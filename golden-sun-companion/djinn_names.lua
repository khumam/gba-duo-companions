-- Djinn names, in the order the ROM stores them (plain text at 0x080E79E on the AGSI ROM).
-- Ownership isn't mapped yet, so every slot is shown as not collected.
local function column(element, color, names)
  local list = {}
  for i, name in ipairs(names) do list[i] = { name = name, locked = true } end
  return { element = element, color = color, djinn = list }
end

return {
  column("VENUS", "#C98B3C", { "Flint", "Granite", "Quartz", "Vine", "Sap", "Ground", "Bane" }),
  column("MERCURY", "#4AA3E0", { "Fizz", "Sleet", "Mist", "Spritz", "Hail", "Tonic", "Dew" }),
  column("MARS", "#E5584B", { "Forge", "Fever", "Corona", "Scorch", "Ember", "Flash", "Torch" }),
  column("JUPITER", "#B58CE0", { "Gust", "Breeze", "Zephyr", "Smog", "Kite", "Squall", "Luff" }),
}
