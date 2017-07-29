-- Alpego KF 7-300 Fabyte Modding
-- script unificato Alpego FS17 By fcelsa (Team FSI Modding)
-- animazione rulli e piedini di supporto, trigger, suoni, salvataggio e lettura attributes
-- setting plough / cultivator for cultiplough spec by TyKonKet
Alpego = {};

function Alpego.prerequisitesPresent(specializations)
    return true;
end;

function Alpego:preLoad(savegame)
    self.setStato = Alpego.setStato;
end;

function Alpego:load(savegame)
    
    -- rulli
    self.Base_rulli_animName = getXMLString(self.xmlFile, "vehicle.attaccorulli#animName");
    self.rulliSound = SoundUtil.loadSample(self.xmlFile, {}, "vehicle.ploughTurnSound", nil, self.baseDirectory);
    self.rulliGiu = false;
    
    -- supporti e relativo trigger
    self.supportSxAnimName = getXMLString(self.xmlFile, "vehicle.suppSx#animName");
    self.supportDxAnimName = getXMLString(self.xmlFile, "vehicle.suppDx#animName");
    self.controlTrigger = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.controlTrigger#index"));
    self.controlTrigger2 = Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.controlTrigger2#index"));
    addTrigger(self.controlTrigger, "ControlTriggerCallback", self);
    addTrigger(self.controlTrigger2, "ControlTriggerCallback2", self);
    self.playerIsInControlTrigger = false;
    self.playerIsInControlTrigger2 = false;
    self.supportLeftLowered = true;
    self.supportRightLowered = true;
    self.supportSound = SoundUtil.loadSample(self.xmlFile, {}, "vehicle.supportSound", nil, self.baseDirectory);
    self.okAttaccato = false;

end;

function Alpego:postLoad(savegame)
    if savegame ~= nil and not savegame.resetVehicles then
        local posizioneRulli = getXMLBool(savegame.xmlFile, savegame.key .. "#rulliGiu");
        if posizioneRulli then
            self:playAnimation(self.Base_rulli_animName, 1, 0, true);
        else
            self:playAnimation(self.Base_rulli_animName, -1, 0, true);
        end
        local supportoSx = getXMLBool(savegame.xmlFile, savegame.key .. "#supportLeftLowered");
        if supportoSx then
            self:playAnimation(self.supportSxAnimName, 1, 0, true);
        else
            self:playAnimation(self.supportSxAnimName, -1, 0, true);
        end
        local supportoDx = getXMLBool(savegame.xmlFile, savegame.key .. "#supportRightLowered");
        if supportoDx then
            self:playAnimation(self.supportDxAnimName, 1, 0, true);
        else
            self:playAnimation(self.supportDxAnimName, -1, 0, true);
        end
        self:setStato(posizioneRulli, supportoSx, supportoDx);
    end;
end;

function Alpego:ControlTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
        if onEnter then
            self.playerIsInControlTrigger = true;
        elseif onLeave then
            self.playerIsInControlTrigger = false;
        end;
    end;
end;

function Alpego:ControlTriggerCallback2(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
    if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
        if onEnter then
            self.playerIsInControlTrigger2 = true;
        elseif onLeave then
            self.playerIsInControlTrigger2 = false;
        end;
    end;
end;

function Alpego:delete()
    -- rulli
    SoundUtil.deleteSample(self.rulliSound);
    
    -- supporti e relativo trigger
    removeTrigger(self.controlTrigger);
    removeTrigger(self.controlTrigger2);
    SoundUtil.deleteSample(self.supportSound);
end;

function Alpego:readStream(streamId, connection)
    local rulli = streamReadBool(streamId);
    if rulli then
        self:playAnimation(self.Base_rulli_animName, 1, 0, true);
    else
        self:playAnimation(self.Base_rulli_animName, -1, 0, true);
    end
    local leftLow = streamReadBool(streamId);
    if leftLow then
        self:playAnimation(self.supportSxAnimName, 1, 0, true);
    else
        self:playAnimation(self.supportSxAnimName, -1, 0, true);
    end
    local rightLow = streamReadBool(streamId);
    if rightLow then
        self:playAnimation(self.supportDxAnimName, 1, 0, true);
    else
        self:playAnimation(self.supportDxAnimName, -1, 0, true);
    end
    self:setStato(rulli, leftLow, rightLow);
end;

function Alpego:writeStream(streamId, connection)
    streamWriteBool(streamId, self.rulliGiu);
    streamWriteBool(streamId, self.supportLeftLowered);
    streamWriteBool(streamId, self.supportRightLowered);
end;

function Alpego:mouseEvent(posX, posY, isDown, isUp, button)
end;

function Alpego:keyEvent(unicode, sym, modifier, isDown)
end;

function Alpego:onAttach()
    self.okAttaccato = true;
end;

function Alpego:onDetach()
    if (self.supportLeftLowered == false or self.supportRightLowered == false) and self.okAttaccato and self.wasEntered then
        if g_currentMission.player == self.wasEntered then
            g_currentMission:showBlinkingWarning(g_i18n:getText("piedini_low"), 2500);
        end;
    end;
    self.okAttaccato = false;
    self.wasEntered = false;
end;

function Alpego:update(dt)
    
    if self.attacherVehicle ~= nil then
        if self.attacherVehicle.isEntered and self.okAttaccato then
            self.wasEntered = g_currentMission.player;
        else
            self.wasEntered = false;
        end;
    end;

    -- rulli
    if self:getIsActiveForInput() then
        if self.rulliGiu then 
            g_currentMission:addHelpButtonText(g_i18n:getText("input_RULLI_UP"), InputBinding.RULLI_UP);
        else
            g_currentMission:addHelpButtonText(g_i18n:getText("input_RULLI_DOWN"), InputBinding.RULLI_DOWN);
        end;
        if InputBinding.hasEvent(InputBinding.RULLI_UP, true) and self.rulliGiu then
            self:playAnimation(self.Base_rulli_animName, -1);
            AlpegoEvent.sendEvent(self, false, self.supportLeftLowered, self.supportRightLowered);
        elseif InputBinding.hasEvent(InputBinding.RULLI_DOWN, true) and not self.rulliGiu then
            self:playAnimation(self.Base_rulli_animName, 1);
            AlpegoEvent.sendEvent(self, true, self.supportLeftLowered, self.supportRightLowered);
        end;
        if self.Base_rulli_animName ~= nil and self:getIsAnimationPlaying(self.Base_rulli_animName) then
            SoundUtil.playSample(self.rulliSound, 0, 0);
        else
            SoundUtil.stopSample(self.rulliSound, true);
        end;
    end;
    
    -- piedini e trigger
    if g_currentMission.player ~= nil and g_currentMission.player.isEntered then
        local px, py, pz = getWorldTranslation(g_currentMission.player.rootNode);
        local tx, ty, tz = getWorldTranslation(self.controlTrigger);
        local t2x, t2y, t2z = getWorldTranslation(self.controlTrigger2);
        if Utils.vector3Length(px - tx, py - ty, pz - tz) < 2.5 then
            g_currentMission:addHelpButtonText(g_i18n:getText("input_SUPPORT_UP_DOWN"), InputBinding.SUPPORT_UP_DOWN);
            if InputBinding.hasEvent(InputBinding.SUPPORT_UP_DOWN) then
                SoundUtil.playSample(self.supportSound, 1, 0);
                if self.supportLeftLowered then
                    self:playAnimation(self.supportSxAnimName, -1);
                    AlpegoEvent.sendEvent(self, self.rulliGiu, false, self.supportRightLowered);
                else
                    self:playAnimation(self.supportSxAnimName, 1);
                    AlpegoEvent.sendEvent(self, self.rulliGiu, true, self.supportRightLowered);
                end;
            end;
        elseif Utils.vector3Length(px - t2x, py - t2y, pz - t2z) < 2.5 then
            g_currentMission:addHelpButtonText(g_i18n:getText("input_SUPPORT_UP_DOWN"), InputBinding.SUPPORT_UP_DOWN);
            if InputBinding.hasEvent(InputBinding.SUPPORT_UP_DOWN) then
                SoundUtil.playSample(self.supportSound, 1, 0);
                if self.supportRightLowered then
                    self:playAnimation(self.supportDxAnimName, -1);
                    AlpegoEvent.sendEvent(self, self.rulliGiu, self.supportLeftLowered, false);
                else
                    self:playAnimation(self.supportDxAnimName, 1);
                    AlpegoEvent.sendEvent(self, self.rulliGiu, self.supportLeftLowered, true);
                end;
            end;
        end;
    end;
end;

function Alpego:updateTick(dt)
end;

function Alpego:draw()
    if self.isClient then
        if (self.supportLeftLowered == true or self.supportRightLowered == true) and self.okAttaccato then
            g_currentMission:addExtraPrintText(g_i18n:getText("info_piedinihowto"));
            if self.movingDirection ~= 0 and self.ploughHasGroundContact and self.lastSpeed > 0.002 then
                g_currentMission:showBlinkingWarning(g_i18n:getText("info_piedini_run"), 4000);
                if self:getIsHired() then
                    local rootVehicle = self:getRootAttacherVehicle();
                    rootVehicle:stopAIVehicle(AIVehicle.STOP_REASON_BLOCKED_BY_OBJECT);
                    if self.cp ~= nil then
                        self.cp.hasFinishedWork = true;
                    end;
                end;
            end;
        end;
    end;
end;

function Alpego:getSaveAttributesAndNodes(nodeIdent)
    local attributes = 'rulliGiu="' .. tostring(self.rulliGiu) .. '" supportLeftLowered="' .. tostring(self.supportLeftLowered) .. '" supportRightLowered="' .. tostring(self.supportRightLowered) .. '"';
    local nodes = nil;
    return attributes, nodes;
end;

function Alpego:setStato(posizioneRulli, supportoSx, supportoDx)
    --print(string.format("Alpego:setStato(posizioneRulli:%s, supportoSx:%s, supportoDx:%s)", posizioneRulli, supportoSx, supportoDx));
    self.rulliGiu = posizioneRulli;
    if not self.rulliGiu then
        self:setCultiPloughMode(CultiPlough.MODES.PLOUGH);
    else
        self:setCultiPloughMode(CultiPlough.MODES.CULTIVATOR);
    end;
    self.supportLeftLowered = supportoSx;
    self.supportRightLowered = supportoDx;
end;

-- Alpego client/server event
AlpegoEvent = {}
AlpegoEvent_mt = Class(AlpegoEvent, Event)

InitEventClass(AlpegoEvent, "AlpegoEvent");

function AlpegoEvent:emptyNew()
    local self = Event:new(AlpegoEvent_mt);
    return self;
end;

function AlpegoEvent:new(object, posizioneRulli, supportoSx, supportoDx)
    local self = AlpegoEvent:emptyNew();
    self.object = object;
    self.posizioneRulli = posizioneRulli;
    self.supportoSx = supportoSx;
    self.supportoDx = supportoDx;
    return self;
end;

function AlpegoEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object);
    streamWriteBool(streamId, self.posizioneRulli);
    streamWriteBool(streamId, self.supportoSx);
    streamWriteBool(streamId, self.supportoDx);
end;

function AlpegoEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId);
    self.posizioneRulli = streamReadBool(streamId);
    self.supportoSx = streamReadBool(streamId);
    self.supportoDx = streamReadBool(streamId);
    self:run(connection);
end;

function AlpegoEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(AlpegoEvent:new(self.object, self.posizioneRulli, self.supportoSx, self.supportoDx), false, nil, self.object);
    end;
    if self.object ~= nil then
        self.object:setStato(self.posizioneRulli, self.supportoSx, self.supportoDx);
    end
end;

function AlpegoEvent.sendEvent(object, posizioneRulli, supportoSx, supportoDx)
    if g_server ~= nil then
        g_server:broadcastEvent(AlpegoEvent:new(object, posizioneRulli, supportoSx, supportoDx), true, nil, object);
    else
        g_client:getServerConnection():sendEvent(AlpegoEvent:new(object, posizioneRulli, supportoSx, supportoDx));
    end;
end;
