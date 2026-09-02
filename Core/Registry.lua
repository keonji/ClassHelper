-- Core/Registry.lua: validated registration and deterministic lookup. Shared code
-- must not branch on specific class, race, or spec tokens.

local addonName, ns = ...

local Registry = {}
ns.Registry = Registry

function Registry:_Bucket(kind)
    if not self.buckets then
        self.buckets = {}
    end
    local bucket = self.buckets[kind]
    if not bucket then
        bucket = { byKey = {}, ordered = {} }
        self.buckets[kind] = bucket
    end
    return bucket
end

function Registry:Register(kind, key, value)
    assert(type(kind) == "string" and kind ~= "", "registry kind is required")
    assert(type(key) == "string" and key ~= "", "registry key is required")
    assert(type(value) == "table", "registry value must be a table")

    local bucket = self:_Bucket(kind)
    assert(not bucket.byKey[key], "duplicate " .. kind .. ": " .. key)

    local record = {}
    for field, fieldValue in pairs(value) do
        record[field] = fieldValue
    end
    record.key = key

    bucket.byKey[key] = record
    bucket.ordered[#bucket.ordered + 1] = record
    return record
end

function Registry:Get(kind, key)
    local bucket = self.buckets and self.buckets[kind]
    if not bucket then
        return nil
    end
    return bucket.byKey[key]
end

function Registry:Has(kind, key)
    return self:Get(kind, key) ~= nil
end

function Registry:List(kind)
    local bucket = self.buckets and self.buckets[kind]
    if not bucket then
        return {}
    end
    return bucket.ordered
end
