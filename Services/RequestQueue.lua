local addonName, ns = ...

local RequestQueue = {}
ns.RequestQueue = RequestQueue

function RequestQueue.New(options)
    options = options or {}
    local dispatchInterval = options.dispatchInterval or 0.4
    local pollInterval = options.pollInterval or 0.5
    local timeout = options.timeout or 8
    local maxChecks = options.maxChecks or 16
    local maxActive = options.maxActive or 4
    local onError = options.onError

    local queue = {
        elapsed = 0,
        nextDispatchAt = dispatchInterval,
        pending = {},
        active = {},
        keys = {},
    }

    local function drop(job)
        queue.keys[job.key] = nil
    end

    local function finish(job, state, payload, reason)
        drop(job)
        if job.handlers.complete then
            local ok, err = pcall(job.handlers.complete, state, payload, reason)
            if not ok and onError then onError(err) end
        end
    end

    function queue:Enqueue(key, handlers)
        if not key or self.keys[key] then return end
        self.keys[key] = true
        self.pending[#self.pending + 1] = {
            key = key,
            handlers = handlers,
            created = self.elapsed,
        }
    end

    function queue:Cancel(key)
        if not self.keys[key] then return end
        drop({ key = key })
        for index = #self.pending, 1, -1 do
            if self.pending[index].key == key then
                table.remove(self.pending, index)
                return
            end
        end
        for index = #self.active, 1, -1 do
            if self.active[index].key == key then
                table.remove(self.active, index)
                return
            end
        end
    end

    function queue:Has(key)
        return self.keys[key] == true
    end

    function queue:Count()
        local count = 0
        for index = 1, #self.pending do
            if self.keys[self.pending[index].key] then count = count + 1 end
        end
        for index = 1, #self.active do
            if self.keys[self.active[index].key] then count = count + 1 end
        end
        return count
    end

    function queue:Update(elapsed)
        self.elapsed = self.elapsed + (elapsed or 0)

        for index = #self.pending, 1, -1 do
            local job = self.pending[index]
            if self.elapsed - job.created >= timeout then
                if self.keys[job.key] then finish(job, "failed", nil, "timeout") end
                table.remove(self.pending, index)
            end
        end

        while self.elapsed >= self.nextDispatchAt do
            if #self.active >= maxActive then
                self.nextDispatchAt = self.elapsed
                break
            end

            local job, jobIndex
            for index = 1, #self.pending do
                if self.keys[self.pending[index].key] then
                    job = self.pending[index]
                    jobIndex = index
                    break
                end
            end

            if not job then
                self.nextDispatchAt = self.elapsed + dispatchInterval
                break
            end

            self.nextDispatchAt = self.nextDispatchAt + dispatchInterval
            table.remove(self.pending, jobIndex)

            if job.handlers.dispatch then
                local ok, err = pcall(job.handlers.dispatch)
                if not ok then
                    if onError then pcall(onError, "dispatch_error: " .. tostring(err)) end
                    drop(job)
                end
            end

            if self.keys[job.key] then
                job.started = self.elapsed
                job.nextCheckAt = self.elapsed + pollInterval
                job.checks = 0
                self.active[#self.active + 1] = job
            end
        end

        local remaining = {}
        for index = 1, #self.active do
            local job = self.active[index]
            if not self.keys[job.key] then
                -- already finished or cancelled
            elseif self.elapsed - job.started >= timeout then
                finish(job, "failed", nil, "timeout")
            elseif self.elapsed >= job.nextCheckAt then
                job.checks = job.checks + 1
                if job.checks >= maxChecks then
                    finish(job, "failed", nil, "checks")
                else
                    local ok, done, payload = pcall(job.handlers.poll)
                    if not ok then
                        if onError then pcall(onError, "poll_error: " .. tostring(done)) end
                        finish(job, "failed", nil, "poll_error")
                    elseif done then
                        finish(job, "success", payload, "resolved")
                    else
                        job.nextCheckAt = self.elapsed + pollInterval
                        remaining[#remaining + 1] = job
                    end
                end
            else
                remaining[#remaining + 1] = job
            end
        end
        self.active = remaining
    end

    return queue
end