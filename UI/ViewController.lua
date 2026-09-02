-- UI/ViewController.lua: owns the current view generation. Each new view cancels
-- the previous view's resolver subscriptions through a single owner token so stale
-- item callbacks can never reach a retired view.

local addonName, ns = ...

local ViewController = {}
ns.ViewController = ViewController

function ViewController.New(itemResolver)
    local controller = {
        itemResolver = itemResolver,
        generation = 0,
        view = nil,
    }

    local function copyContext(context)
        local copy = {}
        for key, value in pairs(context) do
            copy[key] = value
        end
        return copy
    end

    function controller:CancelCurrent()
        local view = self.view
        if view then
            self.itemResolver:CancelOwner(view.ownerToken)
        end
    end

    function controller:Begin(context)
        context = context or {}
        self:CancelCurrent()
        self.generation = self.generation + 1
        local generation = self.generation
        local view = {
            generation = generation,
            ownerToken = "view:" .. generation,
            context = copyContext(context),
        }
        self.view = view
        return view
    end

    function controller:Current()
        return self.view
    end

    function controller:IsCurrent(generation)
        local view = self.view
        return view ~= nil and view.generation == generation
    end

    function controller:Close()
        self:CancelCurrent()
        self.view = nil
    end

    return controller
end
