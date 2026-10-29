SnitchSplit = {}

---Splits a donation into platform fee, tax and the streamer's payout.
---All values are whole dollars; rounding always favours the streamer.
---@param gross integer
---@param fee_percent number
---@param tax_percent number
---@param tax_base 'afterFee'|'gross'
---@return { gross: integer, fee: integer, tax: integer, net: integer }
function SnitchSplit.Calculate(gross, fee_percent, tax_percent, tax_base)
    gross = math.floor(gross)
    local fee = math.floor(gross * fee_percent / 100)
    local taxable = tax_base == 'gross' and gross or gross - fee
    local tax = math.floor(taxable * tax_percent / 100)
    local net = gross - fee - tax
    if net < 0 then
        tax = math.max(0, tax + net)
        net = 0
    end
    return { gross = gross, fee = fee, tax = tax, net = net }
end

function SnitchSplit.FromConfig(gross)
    local donations = Config.Donations
    return SnitchSplit.Calculate(
        gross,
        donations.PlatformFeePercent,
        donations.TaxPercent,
        donations.TaxBase
    )
end
