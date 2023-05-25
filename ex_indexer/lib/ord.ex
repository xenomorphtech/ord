defmodule Ord do
    def read(bin) do
        case bin do
        <<0x20, pubkey::binary-32, 0xac, rest::binary>> ->
            #some transfers insert junk like <<6, 69, 121, 255, 234, 135, 1, 117, 0, 99>>
            #so skip to the if
            case :binary.split(rest, <<0,0x63, 3,"ord", 1,1>>) do
            [_, <<sct, ct::binary-size(sct), 0x00, rest::binary>>] ->
                body = read_body(rest)
                %{content_type: ct, body: body}
            _ -> nil
            end
        _ -> nil
        end
    end

    def read_body(bin, acc \\ "") do
        case bin do
            #OP_ENDIF
            <<0x68>> -> acc
            #N/A Push
            <<size, payload::binary-size(size), rest::binary>> when size in 0x01..0x4b ->
                read_body(rest, acc <> payload)
            #OP_PUSHDATA1
            <<0x4c, size, payload::binary-size(size), rest::binary>> ->
                read_body(rest, acc <> payload)
            #OP_PUSHDATA2
            <<0x4d, size::16-little, payload::binary-size(size), rest::binary>> -> 
                read_body(rest, acc <> payload)
        end
    end
end