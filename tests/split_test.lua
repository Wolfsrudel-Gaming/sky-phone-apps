-- Run from the repository root: lua5.4 tests/split_test.lua
-- Must stay in sync with src/snitch/src/shared/split.test.ts.

dofile('snitch/shared/split.lua')

local function check(name, actual, expected)
    for _, key in ipairs({ 'gross', 'fee', 'tax', 'net' }) do
        if actual[key] ~= expected[key] then
            error(('%s: %s is %s, expected %s'):format(name, key, tostring(actual[key]), tostring(expected[key])))
        end
        if math.type(actual[key]) ~= 'integer' then
            error(('%s: %s is not an integer'):format(name, key))
        end
    end
    print('ok - ' .. name)
end

check('tax from streamer share', SnitchSplit.Calculate(1000, 50, 15, 'afterFee'),
    { gross = 1000, fee = 500, tax = 75, net = 425 })
check('tax from full donation', SnitchSplit.Calculate(1000, 50, 15, 'gross'),
    { gross = 1000, fee = 500, tax = 150, net = 350 })
check('rounds fee and tax down', SnitchSplit.Calculate(33, 50, 15, 'afterFee'),
    { gross = 33, fee = 16, tax = 2, net = 15 })
check('never negative', SnitchSplit.Calculate(100, 90, 50, 'gross'),
    { gross = 100, fee = 90, tax = 10, net = 0 })
