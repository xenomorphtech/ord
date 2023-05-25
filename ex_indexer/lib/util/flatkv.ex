defmodule FlatKV do
    def load_table(table, args) do
        try do
          :ets.new(table, [:ordered_set, :named_table, :public, {:write_concurrency, true}, {:read_concurrency, true}])
          if args[:index] do
            :ets.new(:"#{table}_index", [:ordered_set, :named_table, :public, {:write_concurrency, true}, {:read_concurrency, true}])
          end
          fd = load_table_1(table, args)
          :persistent_term.put({:flatkv_fd, table}, %{fd: fd, args: args})
        catch
          :error, :badarg -> IO.inspect({:load_table, TableExists, table})
        end
    end

    defp load_table_1(table, args) do
        File.mkdir_p!(args.path)
        #:raw, 
        {:ok, fd} = :file.open(args.path<>"/#{table}", [:read, :write, :append, :binary, {:read_ahead, 1048576}, :sync])
        load_table_terms(fd, args)
        fd
    end

    defp load_table_terms(fd, args) do
        case :file.read(fd,4) do
            :eof -> :ok
            {:ok, <<size::32-little>>} ->
                {:ok, data} = :file.read(fd, size)
                list_of_mutations = :erlang.binary_to_term(data)
                Enum.each(list_of_mutations, fn
                    {:merge, table, key, value}->
                        try do
                            old_map = :ets.lookup_element(table, key, 2)
                            map = merge_nested(old_map, value)
                            if map != old_map do
                                index_add(table, key, map, args)
                                :ets.insert(table, {key, map})
                            end
                        catch
                            :error, :badarg ->
                                index_add(table, key, value, args)
                                :ets.insert(table, {key, value})
                        end
                    {:insert, table, key, value}->
                        index_add(table, key, value, args)
                        :ets.insert(table, {key, value})
                    {:delete, table, key, _}-> :ets.delete(table, key)
                end)
                load_table_terms(fd, args)
        end
    end

    defp index_add(table, key, map, args) do
        index_map = if args[:index], do: Map.take(map, args.index)
        if index_map do
            index_delete(table, key, args)
            index_tuple = :erlang.list_to_tuple([key] ++ Enum.map(args.index, &index_map[&1]))
            :ets.insert(:"#{table}_index", {index_tuple, key})
        end
    end

    defp index_delete(table, key, args) do
        if args[:index] do
            index_tuple = :erlang.list_to_tuple([key] ++ Enum.map(args.index, & &1 && :_))
            :ets.match_delete(:"#{table}_index", {index_tuple, :_})
        end
    end

    def merge_nested(left, right) do
        Map.merge(left, right, &merge_nested_resolve/3)
    end

    defp merge_nested_resolve(_, left, right) do
        case {is_map(left), is_map(right)} do
            {true, true} -> merge_nested(left, right)
            _ -> right
        end
    end

    def reload_table(table, args) do
        %{fd: fd, args: args} = :persistent_term.get({:flatkv_fd, table})
        table in :ets.all() && :ets.delete(table)
        :"#{table}_index" in :ets.all() && :ets.delete(:"#{table}_index")
        :ok = :file.close(fd)
        load_table(table, args)
    end

    def insert(table, key, value, subscription \\ []) do
        ts_m = :os.system_time(1000)
        %{fd: fd, args: args} = :persistent_term.get({:flatkv_fd, table})

        map = Map.merge(value, %{uuid: key, _tsc: ts_m, _tsu: ts_m})

        bin = :erlang.term_to_binary([{:insert, table, key, map}])
        :ok = :file.write(fd, <<byte_size(bin)::32-little, bin::binary>>)
        :ets.insert(table, {key, map})

        index_add(table, key, map, args)
        #subscription && proc_subscriptions_new(table, key, map, subscription)
        map
    end

    def merge(table, key, diff_map, subscription \\ []) do
        ts_m = :os.system_time(1000)
        %{fd: fd, args: args} = :persistent_term.get({:flatkv_fd, table})

        try do
            old_map = :ets.lookup_element(table, key, 2)
            map = merge_nested(old_map, diff_map)
    
            if map == old_map do
                map
            else
                map = Map.put(map, :_tsu, ts_m)
    
                bin = :erlang.term_to_binary([{:merge, table, key, map}])
                :ok = :file.write(fd, <<byte_size(bin)::32-little,bin::binary>>)
                :ets.insert(table, {key, map})
    
                index_add(table, key, map, args)
                #subscription && proc_subscriptions_merge(table, key, map, diff_map, subscription)
                map
            end
        catch
            :error, :badarg -> insert(table, key, diff_map, subscription)
        end
    end

    def delete(table, key, subscription \\ []) do
        %{fd: fd, args: args} = :persistent_term.get({:flatkv_fd, table})

        bin = :erlang.term_to_binary([{:delete, table, key, nil}])
        :ok = :file.write(fd, <<byte_size(bin)::32-little, bin::binary>>)

        :ets.delete(table, key)
        index_delete(table, key, args)
        #subscription && proc_subscriptions_delete(table, key, map, subscription)
    end

    def get(table, key) do
        try do
            :ets.lookup_element(table, key, 2)
        catch
            :error, :badarg -> nil
        end
    end

    def get(table) do
        :ets.select(table, [{{:_, :"$1"}, [], [:"$1"]}])
    end

    def exists(table, key) do
        try do
            :ets.lookup_element(table, key, 1)
            true
        catch
            :error, :badarg -> false
        end
    end

    def match_object(table, match_spec) do
        :ets.match_object(table, match_spec) |> Enum.map(&elem(&1, 1))
    end

    def match_object_index(table, map) do
        %{args: args} = :persistent_term.get({:flatkv_fd, table})
        if !args[:index], do: throw(%{error: :no_index})
    
        index_args = [:key] ++ args.index
        index_tuple = :erlang.list_to_tuple(
            Enum.map(index_args, fn index ->
                case Map.fetch(map, index) do
                    :error -> :_
                    {:ok, value} -> value
                end
            end)
        )
    
        match_spec = [{{index_tuple, :"$2"}, [], [:"$2"]}]
        :ets.select(:"#{table}_index", match_spec)
    end

    def batch(table, list) do
        %{fd: fd, args: args} = :persistent_term.get({:flatkv_fd, table})
        bin = :erlang.term_to_binary(list)
        :ok = :file.write(fd, <<byte_size(bin)::32-little, bin::binary>>)
        Enum.each(list, fn
            {:insert, table, key, value} -> insert(table, key, value)
            {:merge, table, key, value} -> merge(table, key, value)
            {:delete, table, key, _} -> delete(table, key)
        end)
    end

    def snapshot(table, output_path) do
        %{args: args} = :persistent_term.get({:flatkv_fd, table})

        File.mkdir_p!(output_path)
        {"", 0} = System.shell("cp --reflink=always #{args.path}/#{table} #{output_path}", [{:stderr_to_stdout, true}])
    end

    def restore_from_snapshot(table, path) do
    end
end
