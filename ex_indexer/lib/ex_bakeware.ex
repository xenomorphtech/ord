defmodule Ord.Bakeware do
    use Bakeware.Script
    require Logger

    @impl Bakeware.Script
    def main(args) do
        Ord.Ex.start(nil, args)
        receive do end
        0
    end
end