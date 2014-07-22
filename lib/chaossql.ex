defmodule Chaos.SQL do
    require Regex
    import Chaos, only: [make: 2]

    @regexp ~r"^\s*CREATE TABLE\s+(?:IF NOT EXISTS)\s+(?<table>\w+)\s+\((?<columns>.*)\)"im

    def read_sql(text, extra \\ %{}, delimiter \\ ";") do
        extra = extra |> Enum.into(%{})

        String.split(text, delimiter) 
        |> Enum.map(fn(term)-> read_term(term, extra) end) 
        |> List.flatten
    end

    defp read_term(term, extra) do
        String.strip(term) |> String.replace("\n", "") 
        |> read_table(extra)
    end

    defp read_table(term, extra) do
        case Regex.named_captures(@regexp, term) do
            %{"table" => table, "columns" => columns} ->
                count = Dict.get(extra, table, 1000) 
                opts = columns
                    |> String.split(",")
                    |> Enum.map fn(column)-> 
                        [column|_] = String.split(column, "#", parts: 2)
                        [column|_] = String.split(column, "--", parts: 2)

                        ret = String.strip(column) 
                            |> String.split(" ") 
                            |> read_row_name

                        {name, opts} = case ret do
                            nil -> {nil, nil}
                            {name, opts} -> {name, opts}
                        end

                        {name, Dict.merge(opts, Dict.get(extra, "#{table}.#{name}", %{}))}
                    end 

                make(opts, count) 
                |> Stream.map(fn(data)-> 
                    format_line(data, table)
                end)
                |> Enum.filter fn(x)-> x != nil end

            nil -> []
        end
    end

    defp read_row_name([name|tail]) when length(tail) >= 1, do: read_row_type(name, tail)
    defp read_row_name(_), do: {nil, %{}}
    defp read_row_type(name, [type|tail]) do
        {type, len} = case String.split(String.upcase(type), "(", parts: 2) do
            [type] -> {type, nil}
            [type, len] -> 
                case Integer.parse(len) do
                    {len, _} -> {type, len}
                    :error -> {type, len}
                end
        end

        cond do
            type in ["INT", "BIGINT"] -> 
                read_row_params(name, :int, %{}, tail)
            type in ["DATETIME", "DATE"] -> 
                read_row_params(name, :date, %{}, tail)
            type in ["CHAR", "VARCHAR"] and len > 16 ->
                read_row_params(name, :uuid, %{}, tail)
            type in ["CHAR", "VARCHAR"] ->
                read_row_params(name, :string, %{mask: "{w}~#{len}"}, tail)
            type in ["TEXT", "BLOB", "LONGBLOB"] -> 
                read_row_params(name, :uuid, %{}, tail)
            true -> {nil, %{}}
        end
    end
    defp read_row_params(name, type, params, []) do
        {String.to_atom(name), Dict.merge(params, %{
            type: type
        })}
    end
    defp read_row_params(name, type, params, [head|tail]) do
        case String.upcase(head) do
            "AUTO_INCREMENT" -> {nil, %{}}
            "DEFAULT" -> nil
            #"NULL" -> nil
            _ -> read_row_params(name, type, params, tail)
        end
    end

    defp format_line(data, table_name) do
        {l1,l2} = data |> Enum.reduce {[], []}, 
            fn({key, val}, {l1,l2}) -> {[key|l1],[val|l2]} end
        "INSERT INTO #{table_name} (#{Enum.join(l1, ",")}) VALUES (#{Enum.join(l2, ",")});"
    end
end