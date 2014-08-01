Exchaos
=======

## Chaos.make(opts, count, names \\ true)

opts = [
    key1: %{
        type: :uuid/:int/:float/:date/:string,   # Type
        count: X,                                # Optional count of generated values
        value: ...,                              # Only value
        values: [..., ..., ...],                 # Random from list value
        fn: fn(x)-> x end,                       # Fn generated value
        range: X..Y,                             # Random from range for :int, :float, :date

        mask: "%[first]%[second]",                     # :string mask from data
        data %{first: ["A", "B"], second: ["C", "D"]}  # Random from: AC AD BC BD

        mask: "{d}{w}{W}{h}{l}{*}~10"            # :string from expression
                                                 # {d} num, {w} letter, {W} LETTER
                                                 # {h} num | LETTER  {l} num | letter
                                                 # {*} any
                                                 # ~N repeat N times
    }
]

count = X items

names = 
    true %{a: ..., b: ...}
    false [..., ...]


