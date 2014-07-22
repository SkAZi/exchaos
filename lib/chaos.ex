defmodule Chaos do

    def make(opts, count, names \\ true) do
        params = precompile_params(opts)
        Stream.map 1..count, fn(_x)->
            res = Enum.map(params, fn
                {name, {:value, value}} ->
                    if names, do: {name, value}, else: value

                {name, {:values, values}} ->
                    if names, do: {name, random_element(values)}, else: random_element(values)
                
                {name, {:fn, f}} ->
                    if names, do: {name, f.()}, else: f.()    
            end) 

            if names, do: res |> Enum.into(%{}), else: res
        end
    end


    def precompile_params(params) do
        params 
        |> Enum.map(fn({name, opts})->
                {name, precompile_param(opts)}
            (nil) -> 
                {nil, nil}
        end) |> Enum.filter(fn({_name, op}) -> 
            op != nil
        end)
    end

    defp precompile_param(%{value: value}), 
        do: {:value, value}
    defp precompile_param(%{values: values}), 
        do: {:values, values}
    defp precompile_param(%{fn: f}), 
        do: {:fn, f}

    defp precompile_param(%{type: :uuid, count: count}), 
        do: {:values, Enum.map(1..count, fn(_x)-> generate_uuid_fn() end)}
    defp precompile_param(%{type: :uuid}), 
        do: {:fn, &generate_uuid_fn/0}

    defp precompile_param(%{type: :int, count: count, range: range}), 
        do: {:values, Enum.map(1..count, generate_int_fn(range))}
    defp precompile_param(%{type: :int, count: count}), 
        do: {:values, Enum.map(1..count, generate_int_fn(1..999999999))}
    defp precompile_param(%{type: :int, range: range}), 
        do: {:fn, fn()-> generate_int_fn(range) end}
    defp precompile_param(%{type: :int}), 
        do: {:fn, fn()-> generate_int_fn(1..999999999) end}

    defp precompile_param(%{type: :float, count: count, range: range}), 
        do: {:values, Enum.map(1..count, generate_float_fn(range))}
    defp precompile_param(%{type: :float, count: count}), 
        do: {:values, Enum.map(1..count, :random.uniform)}
    defp precompile_param(%{type: :float, range: range}), 
        do: {:fn, fn()-> generate_float_fn(range) end}
    defp precompile_param(%{type: :float}), 
        do: {:fn, fn()-> :random.uniform end}

    defp precompile_param(%{type: :date, count: count, range: range}), 
        do: {:values, Enum.map(1..count, generate_date_fn(range.first, range.last))}
    defp precompile_param(%{type: :date, count: count}), 
        do: {:values, Enum.map(1..count, generate_date_fn("1970-01-01", "2014-01-01"))}
    defp precompile_param(%{type: :date, range: range}), 
        do: {:fn, fn()-> generate_date_fn(range.first, range.last) end}
    defp precompile_param(%{type: :date}),
        do: {:fn, fn()-> generate_date_fn("2000-01-01", "2014-01-01")end}

    defp precompile_param(%{type: :string, mask: mask, data: data, count: count}) do 
        f = generate_string_fn(mask, data)
        {:values, Enum.map(1..count, fn(_x)-> f.() end)}
    end
    defp precompile_param(%{type: :string, mask: mask, count: count}) do
        f = generate_string_fn(mask)
        {:values, Enum.map(1..count, fn(_x)-> f.() end)}
    end
    defp precompile_param(%{type: :string, mask: mask, data: data}), 
        do: {:fn, generate_string_fn(mask, data)}
    defp precompile_param(%{type: :string, mask: mask}), 
        do: {:fn, generate_string_fn(mask)}

    defp precompile_param(%{type: :string, value: value}), 
        do: {:value, "\"#{value}\""}
    defp precompile_param(%{value: value}), 
        do: {:value, value}

    defp precompile_param(_), do: nil



    defp random_element(list) do 
        :lists.nth(:random.uniform(length(list)), list)
    end

    defp generate_uuid_fn() do
        use Bitwise
        <<a::32, b::16, c::16, d::16, e::48>> = :crypto.rand_bytes(16)

        ret = (Integer.to_string(a, 16) <> "-" <> 
        Integer.to_string(b, 16) <> "-" <> 
        Integer.to_string(c &&& 0xfff, 16) <> "-" <> 
        Integer.to_string(d &&& 0x3fff ||| 0x8000, 16) <> "-" <> 
        Integer.to_string(e, 16))
        |> String.downcase
        "\"#{ret}\"" 
    end

    defp generate_int_fn(list) when is_list(list), do: generate_int_fn(random_element(list))
    defp generate_int_fn(r), do: :random.uniform(r.last - r.first) + r.first

    defp generate_float_fn(r), do: :random.uniform() * (r.last - r.first) + r.first

    defp generate_date_fn(from, to) do
        ret = generate_int_fn(date_to_int(from)..date_to_int(to))
        |> int_to_date
        "\"#{ret}\""
    end
    defp date_to_int(date) do
        date = String.split(date, "-") 
            |> Enum.map(fn(x)-> Integer.parse(x) end) 
            |> Enum.map(fn({a,_b})-> a end)
            |> List.to_tuple

        :calendar.datetime_to_gregorian_seconds({date,{0,0,0}})
    end
    defp int_to_date(int) do
        case :calendar.gregorian_seconds_to_datetime(int) do
            {{y,m,d},_} -> "#{y}-#{m}-#{d}"
            _ -> "1970-1-1"
        end
    end


    defp generate_string_fn(mask) do
        fn() ->
            ret = Enum.map(parse_string_mask(mask, "", []), fn(f)->
                f.()
            end) |> List.to_string
            "\"#{ret}\""
        end
    end
    defp generate_string_fn(mask, data) do
        fn() ->
            ret = Enum.reduce data, mask, fn({name, values}, ret)->
                String.replace(ret, "%[#{name}]", random_element(values))
            end
            "\"#{ret}\""
        end
    end

    defp parse_string_mask("{d}" <> tail, _last, otp), do: parse_string_mask(tail, "{d}", [fn()-> generate_int_fn(0..9) |> Integer.to_string end|otp])
    defp parse_string_mask("{w}" <> tail, _last, otp), do: parse_string_mask(tail, "{w}", [fn()-> << generate_int_fn(97..122) >> end|otp])
    defp parse_string_mask("{W}" <> tail, _last, otp), do: parse_string_mask(tail, "{W}", [fn()-> << generate_int_fn(65..90) >> end|otp])
    defp parse_string_mask("{h}" <> tail, _last, otp), do: parse_string_mask(tail, "{h}", [fn()-> generate_int_fn([48..57,97..122]) end|otp])
    defp parse_string_mask("{l}" <> tail, _last, otp), do: parse_string_mask(tail, "{l}", [fn()-> generate_int_fn([65..90,97..122]) end|otp])
    defp parse_string_mask("{*}" <> tail, _last, otp), do: parse_string_mask(tail, "\*", [fn()-> generate_int_fn([48..57,65..90,97..122]) end|otp])
    defp parse_string_mask("\\~" <> tail, _last, otp), do: parse_string_mask(tail, "~", [fn()-> "~" end|otp])
    defp parse_string_mask("~" <> tail, last, otp), do: parse_mask_number(tail, [], last, otp)
    defp parse_string_mask(<< x :: utf8, tail :: binary >>, _last, otp), do: parse_string_mask(tail, <<x>>, [fn()-> <<x>> end|otp])
    defp parse_string_mask("", _last, otp), do: Enum.reverse(otp)

    defp parse_mask_number(<< x :: utf8>> <> tail, num, last, otp) when x in 48..57, do: 
        parse_mask_number(tail, [<<x>>|num], last, otp)
    defp parse_mask_number(tail, num, last, otp) do
        {cnt, _} = Enum.reverse(num) |> List.to_string |> Integer.parse
        parse_string_mask(String.duplicate(last, cnt-1) <> tail, "", otp)
    end
end
