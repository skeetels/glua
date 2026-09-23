-- A polling attempt is not evidence that hidden game data was refreshed.
return function(ctx)
    local Store = {}
    Store.__index = Store
    function Store.new(clock)
        return setmetatable({clock=clock, generation=0, records={}, revision=0}, Store)
    end
    function Store:invalidate(reason)
        self.generation=self.generation+1
        self.records={}
        self.reason=reason
        self.revision=self.revision+1
    end
    function Store:observe(key, value, signature, visible, source)
        if not value or not signature then return nil end
        local old=self.records[key]
        local changed=old~=nil and old.signature~=signature
        local at=self.clock()
        -- Hidden changes wake planning, but do not authorize a reset.
        local stamp=visible and at or changed and at or old and old.observedAt
        local verified=visible and at or old and old.verifiedAt
        if changed or not old then self.revision=self.revision+1 end
        self.records[key]={value=value, signature=signature, observedAt=stamp,
            verifiedAt=verified, changedAt=changed and at or old and old.changedAt,
            visible=visible==true, source=source or 'gui', generation=self.generation,
            revision=self.revision}
        return self.records[key]
    end
    function Store:read(key, maxAge, requireVisibleEvidence)
        local r=self.records[key]
        if not r then return nil,'MISSING' end
        local stamp=r.observedAt
        if requireVisibleEvidence then stamp=r.verifiedAt end
        local at=self.clock()
        if not stamp then return nil,'UNVERIFIED_HIDDEN' end
        if stamp>at or at-stamp>maxAge then return nil,'STALE' end
        -- A hidden mutation invalidates previously visible transaction evidence.
        if requireVisibleEvidence and r.changedAt and r.changedAt>stamp then return nil,'CHANGED_HIDDEN' end
        return r.value,nil,r
    end
    function Store:summary()
        local out={generation=self.generation, revision=self.revision, channels={}}
        for key,r in pairs(self.records) do
            out.channels[key]={age=r.observedAt and self.clock()-r.observedAt or nil,
                verifiedAge=r.verifiedAt and self.clock()-r.verifiedAt or nil,
                source=r.source,visible=r.visible,revision=r.revision}
        end
        return out
    end
    ctx.ObservationStore=Store
end
