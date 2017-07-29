-- CultiPlough by TyKonKet (Team FSI Modding)
-- v. 1.0.0  2017-02
--

CultiPlough = {};
CultiPlough.MODES = {};
CultiPlough.MODES.PLOUGH = 1;
CultiPlough.MODES.CULTIVATOR = 2;

function CultiPlough.initSpecialization()
    WorkArea.registerAreaType("cultiplough");
end

function CultiPlough.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(WorkArea, specializations);
end

function CultiPlough:preLoad(savegame)
    self.loadSpeedRotatingPartFromXML = Utils.overwrittenFunction(self.loadSpeedRotatingPartFromXML, CultiPlough.loadSpeedRotatingPartFromXML);
    self.loadWorkAreaFromXML = Utils.overwrittenFunction(self.loadWorkAreaFromXML, CultiPlough.loadWorkAreaFromXML);
end

function CultiPlough:load(savegame)
    self.setRotationMax = SpecializationUtil.callSpecializationsFunction("setRotationMax");
    self.setPloughLimitToField = CultiPlough.setPloughLimitToField;
    self.getIsPloughRotationAllowed = CultiPlough.getIsPloughRotationAllowed;
    self.setCultiPloughMode = CultiPlough.setCultiPloughMode;
    self.getIsFoldAllowed = Utils.overwrittenFunction(self.getIsFoldAllowed, CultiPlough.getIsFoldAllowed);
    self.getIsFoldMiddleAllowed = Utils.overwrittenFunction(self.getIsFoldMiddleAllowed, CultiPlough.getIsFoldMiddleAllowed);
    self.getDirtMultiplier = Utils.overwrittenFunction(self.getDirtMultiplier, CultiPlough.getDirtMultiplier);
    self.getIsSpeedRotatingPartActive = Utils.overwrittenFunction(self.getIsSpeedRotatingPartActive, CultiPlough.getIsSpeedRotatingPartActive);
    self.getSpeedRotatingPartDirection = Utils.overwrittenFunction(self.getSpeedRotatingPartDirection, CultiPlough.getSpeedRotatingPartDirection);
    self.doCheckSpeedLimit = Utils.overwrittenFunction(self.doCheckSpeedLimit, CultiPlough.doCheckSpeedLimit);
    
    self.processPloughAreas = CultiPlough.processPloughAreas;
    
    if next(self.groundReferenceNodes) == nil then
        print("Warning: No ground reference nodes in " .. self.configFileName);
    end
    
    self.rotationPart = {};
    self.rotationPart.turnAnimation = getXMLString(self.xmlFile, "vehicle.rotationPart#turnAnimationName");
    self.rotationPart.foldMinLimit = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.rotationPart#foldMinLimit"), 0);
    self.rotationPart.foldMaxLimit = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.rotationPart#foldMaxLimit"), 1);
    self.rotationPart.limitFoldRotationMax = getXMLBool(self.xmlFile, "vehicle.rotationPart#limitFoldRotationMax");
    self.rotationPart.foldRotationMinLimit = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.rotationPart#foldRotationMinLimit"), 0);
    self.rotationPart.foldRotationMaxLimit = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.rotationPart#foldRotationMaxLimit"), 1);
    self.rotationPart.rotationFoldMinLimit = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.rotationPart#rotationFoldMinLimit"), 0);
    self.rotationPart.rotationFoldMaxLimit = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.rotationPart#rotationFoldMaxLimit"), 1);
    self.rotationPart.rotationAllowedIfLowered = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.rotationPart#rotationAllowedIfLowered"), true);
    
    self.ploughDirectionNode = Utils.getNoNil(Utils.indexToObject(self.components, getXMLString(self.xmlFile, "vehicle.ploughDirectionNode#index")), self.components[1].node);
    
    if self.isClient then
        self.samplePloughTurn = SoundUtil.loadSample(self.xmlFile, {}, "vehicle.ploughTurnSound", nil, self.baseDirectory);
        self.samplePlough = SoundUtil.loadSample(self.xmlFile, {}, "vehicle.ploughSound", nil, self.baseDirectory);
    end
    
    self.rotateLeftToMax = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.rotateLeftToMax#value"), true);
    
    self.aiPlough = {};
    self.aiPlough.animTimeCenterPosition = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.animTimeCenterPosition#value"), 0.5);
    self.aiPlough.rotateEarly = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.aiPlough#rotateEarly"), true);
    
    self.onlyActiveWhenLowered = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.onlyActiveWhenLowered#value"), true);
    
    self.ploughHasGroundContact = false;
    self.rotationMax = false;
    self.ploughContactReportsActive = false;
    self.startActivationTimeout = 2000;
    self.startActivationTime = 0;
    self.lastPloughArea = 0;
    
    self.ploughLimitToField = true;
    self.forcePloughLimitToField = false;
    
    self.showFieldNotOwnedWarning = false;
    self.isPloughSpeedLimitActive = false;
    self.wasTurnAnimationStopped = false;
    
    self.isPloughLowered = false;
    
    self.ploughGroundContactFlag = self:getNextDirtyFlag();
end

function CultiPlough:postLoad(savegame)
    self.cultivatorSpeedLimit = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.speedLimit#cultivatorValue"), self.speedLimit);
    self.ploughSpeedLimit = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.speedLimit#ploughValue"), self.speedLimit);
    self.powerConsumer.ploughMaxForce = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.powerConsumer#ploughMaxForce"), self.powerConsumer.maxForce);
    self.powerConsumer.cultivatorMaxForce = Utils.getNoNil(getXMLFloat(self.xmlFile, "vehicle.powerConsumer#cultivatorMaxForce"), self.powerConsumer.maxForce);
    self:setCultiPloughMode(CultiPlough.MODES.PLOUGH);

end

function CultiPlough:delete()
    if self.isClient then
        SoundUtil.deleteSample(self.samplePlough);
        SoundUtil.deleteSample(self.samplePloughTurn);
    end
end

function CultiPlough:readStream(streamId, connection)
    local rotationMax = streamReadBool(streamId);
    local rotationAllowed = streamReadBool(streamId);
    if rotationAllowed then
        self:setRotationMax(rotationMax, true);
        if self.rotationPart.turnAnimation ~= nil and self.playAnimation ~= nil then
            local turnAnimTime = streamReadFloat32(streamId);
            self:setAnimationTime(self.rotationPart.turnAnimation, turnAnimTime);
            
            if self.updateCylinderedInitial ~= nil then
                self:updateCylinderedInitial(false);
            end
        end
    else
        self.rotationMax = rotationMax;
    end
end

function CultiPlough:writeStream(streamId, connection)
    streamWriteBool(streamId, self.rotationMax);
    if streamWriteBool(streamId, self:getIsPloughRotationAllowed()) then
        if self.rotationPart.turnAnimation ~= nil and self.playAnimation ~= nil then
            local turnAnimTime = self:getAnimationTime(self.rotationPart.turnAnimation);
            streamWriteFloat32(streamId, turnAnimTime);
        end
    end
end

function CultiPlough:readUpdateStream(streamId, timestamp, connection)
    if connection:getIsServer() then
        self.ploughHasGroundContact = streamReadBool(streamId);
        self.showFieldNotOwnedWarning = streamReadBool(streamId);
    end
end

function CultiPlough:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() then
        streamWriteBool(streamId, self.ploughHasGroundContact);
        streamWriteBool(streamId, self.showFieldNotOwnedWarning);
    end
end

function CultiPlough:getSaveAttributesAndNodes(nodeIdent)
    local attributes = "";
    local nodes = "";
    return attributes, nodes;
end

function CultiPlough:mouseEvent(posX, posY, isDown, isUp, button)
    return;
end

function CultiPlough:keyEvent(unicode, sym, modifier, isDown)
    return;
end

function CultiPlough:update(dt)
    if self:getIsActiveForInput() then
        if self.rotationPart.turnAnimation ~= nil then
            if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA) then
                if self:getIsPloughRotationAllowed() then
                    self:setRotationMax(not self.rotationMax);
                end
            end
        end
        if not self.forcePloughLimitToField then
            if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA3) then
                self:setPloughLimitToField(not self.ploughLimitToField);
            end
        end
    end
end

function CultiPlough:updateTick(dt)
    self.isPloughSpeedLimitActive = false;
    if self:getIsActive() then
        self.lastPloughArea = 0;
        local showFieldNotOwnedWarning = false;
        
        if self.isServer then
            local hasGroundContact = self:getIsTypedWorkAreaActive(WorkArea.AREATYPE_CULTIPLOUGH);
            if self.ploughHasGroundContact ~= hasGroundContact then
                self:raiseDirtyFlags(self.ploughGroundContactFlag);
            end
            self.ploughHasGroundContact = hasGroundContact;
        end
        local hasGroundContact = self.ploughHasGroundContact;
        
        if hasGroundContact then
            if self.startActivationTime <= g_currentMission.time then
                self.isPloughSpeedLimitActive = true;
                if not self.onlyActiveWhenLowered or self:isLowered(false) then

                    local workAreas, showWarning, _ = self:getTypedNetworkAreas(WorkArea.AREATYPE_CULTIPLOUGH, true);
                    if self.isServer then
                        showFieldNotOwnedWarning = showWarning;
                        if (table.getn(workAreas) > 0) then
                            local limitToField = self.ploughLimitToField or self.forcePloughLimitToField;
                            local limitGrassDestructionToField = self.ploughLimitToField or self.forcePloughLimitToField;
                            if not g_currentMission:getHasPermission("createFields", self:getOwner()) or g_currentMission.fieldJobManager:isFieldJobActive() then
                                limitToField = true;
                                limitGrassDestructionToField = true;
                            end
                            
                            local dx, _, dz = localDirectionToWorld(self.ploughDirectionNode, 0, 0, 1);
                            local angle = Utils.convertToDensityMapAngle(Utils.getYRotationFromDirection(dx, dz), g_currentMission.terrainDetailAngleMaxValue);
                            
                            local realArea = self:processPloughAreas(workAreas, limitToField, limitGrassDestructionToField, angle);
                            
                            self.lastPloughArea = Utils.areaToHa(realArea, g_currentMission:getFruitPixelsToSqm()); -- 4096px are mapped to 2048m
                            if self.cultiPloughMode == CultiPlough.MODES.CULTIVATOR then
                                g_currentMission.missionStats:updateStats("cultivatedHectares", self.lastPloughArea);
                            end
                            g_currentMission.missionStats:updateStats("workedHectares", self.lastPloughArea);
                        end
                    end

                    -- remove tireTracks
                    for _, workArea in pairs(workAreas) do
                        Utils.eraseTireTrack(workArea[1], workArea[2], workArea[3], workArea[4], workArea[5], workArea[6])
                    end
                    
                end
                g_currentMission.missionStats:updateStats("workedTime", dt / (1000 * 60));
            end
            
            if self.isClient and self:getLastSpeed() > 3 and self:getIsActiveForSound() then
                SoundUtil.playSample(self.samplePlough, 0, 0, nil);
            else
                SoundUtil.stopSample(self.samplePlough);
            end
        else
            if self.isClient then
                SoundUtil.stopSample(self.samplePlough);
            end
        end
        
        if self.rotationPart.turnAnimation ~= nil then
            if self.isClient then
                if self:getIsAnimationPlaying(self.rotationPart.turnAnimation) and self:getIsActiveForSound() then
                    SoundUtil.playSample(self.samplePloughTurn, 0, 0, nil);
                else
                    SoundUtil.stopSample(self.samplePloughTurn);
                end
            end
        end
        
        if self.isServer then
            if showFieldNotOwnedWarning ~= self.showFieldNotOwnedWarning then
                self.showFieldNotOwnedWarning = showFieldNotOwnedWarning;
                self:raiseDirtyFlags(self.ploughGroundContactFlag);
            end
        end
    end
end

function CultiPlough:draw()
    if self:getIsActiveForInput(true) then
        if self.rotationPart.turnAnimation ~= nil then
            if self:getIsPloughRotationAllowed() then
                g_currentMission:addHelpButtonText(g_i18n:getText("action_turnPlough"), InputBinding.IMPLEMENT_EXTRA, nil, GS_PRIO_HIGH);
            end
        end
        
        if g_currentMission:getHasPermission("createFields", self:getOwner()) and not g_currentMission.fieldJobManager:isFieldJobActive() then
            if not self.forcePloughLimitToField then
                if self.ploughLimitToField then
                    g_currentMission:addHelpButtonText(g_i18n:getText("action_allowCreateFields"), InputBinding.IMPLEMENT_EXTRA3, nil, GS_PRIO_NORMAL);
                else
                    g_currentMission:addHelpButtonText(g_i18n:getText("action_limitToFields"), InputBinding.IMPLEMENT_EXTRA3, nil, GS_PRIO_NORMAL);
                end
            end
        end
    end
    
    if self.showFieldNotOwnedWarning then
        g_currentMission:showBlinkingWarning(g_i18n:getText("warning_youDontOwnThisField"));
    end
end

function CultiPlough:onAttach(attacherVehicle)
    self.startActivationTime = g_currentMission.time + self.startActivationTimeout;
    if self.wasTurnAnimationStopped then
        local dir = 1;
        if not self.rotationMax then
            dir = -1;
        end
        self:playAnimation(self.rotationPart.turnAnimation, dir, self:getAnimationTime(self.rotationPart.turnAnimation), true);
        self.wasTurnAnimationStopped = false;
    end
end

function CultiPlough:onDetach()
    self.ploughLimitToField = true;
    if self:getIsAnimationPlaying(self.rotationPart.turnAnimation) then
        self:stopAnimation(self.rotationPart.turnAnimation, true);
        self.wasTurnAnimationStopped = true;
    end
end

function CultiPlough:onActivate()
    return;
end

function CultiPlough:onDeactivate()
    self.showFieldNotOwnedWarning = false;
end

function CultiPlough:onDeactivateSounds()
    if self.isClient then
        SoundUtil.stopSample(self.samplePlough, true);
        SoundUtil.stopSample(self.samplePloughTurn, true);
    end
end

function CultiPlough:onAiRotateCenter(force)
    if self:getIsPloughRotationAllowed() or force then
        if self.rotationPart.turnAnimation ~= nil then
            
            self:setAnimationStopTime(self.rotationPart.turnAnimation, self.aiPlough.animTimeCenterPosition);
            
            local animTime = self:getAnimationTime(self.rotationPart.turnAnimation);
            if animTime < self.aiPlough.animTimeCenterPosition then
                self:playAnimation(self.rotationPart.turnAnimation, 1, animTime, false);
            else
                self:playAnimation(self.rotationPart.turnAnimation, -1, animTime, false);
            end
        end
    end
end

function CultiPlough:onAiRotateLeft(force)
    if self:getIsPloughRotationAllowed() or force then
        self:setRotationMax(self.rotateLeftToMax, true);
    end
end

function CultiPlough:onAiRotateRight(force)
    if self:getIsPloughRotationAllowed() or force then
        self:setRotationMax(not self.rotateLeftToMax, true);
    end
end

function CultiPlough:onAiTurnOn()
    self.ploughLimitToField = true;
end

function CultiPlough:getAiInvertsMarkerOnTurn(turnLeft)
    if self.rotationPart.turnAnimation ~= nil then
        if turnLeft then
            return self.rotationMax ~= self.rotateLeftToMax;
        else
            return self.rotationMax == self.rotateLeftToMax;
        end
    else
        return false;
    end
end

function CultiPlough:getIsAIReadyForWork()
    if self.rotationPart.turnAnimation ~= nil then
        local animTime = self:getAnimationTime(self.rotationPart.turnAnimation);
        if animTime == 0 or animTime == 1 then
            return true;
        else
            if not self:getIsAnimationPlaying(self.rotationPart.turnAnimation) then
                self:setRotationMax(self.rotationMax);
            end
        end
    else
        return true;
    end
end

function CultiPlough:setRotationMax(rotationMax, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(PloughRotationEvent:new(self, rotationMax), nil, nil, self);
        else
            g_client:getServerConnection():sendEvent(PloughRotationEvent:new(self, rotationMax));
        end
    end
    self.rotationMax = rotationMax;
    
    if self.rotationPart.turnAnimation ~= nil then
        local animTime = self:getAnimationTime(self.rotationPart.turnAnimation);
        if self.rotationMax then
            self:playAnimation(self.rotationPart.turnAnimation, 1, animTime, true);
        else
            self:playAnimation(self.rotationPart.turnAnimation, -1, animTime, true);
        end
    end
end

function CultiPlough:setPloughLimitToField(ploughLimitToField, noEventSend)
    if self.ploughLimitToField ~= ploughLimitToField then
        if noEventSend == nil or noEventSend == false then
            if g_server ~= nil then
                g_server:broadcastEvent(PloughLimitToFieldEvent:new(self, ploughLimitToField), nil, nil, self);
            else
                g_client:getServerConnection():sendEvent(PloughLimitToFieldEvent:new(self, ploughLimitToField));
            end
        end
        self.ploughLimitToField = ploughLimitToField;
    end
end

function CultiPlough:getIsPloughRotationAllowed()
    --if self.isPloughLowered then
    --    return false;
    --end
    local foldAnimTime = self.foldAnimTime;
    if foldAnimTime ~= nil and (foldAnimTime > self.rotationPart.rotationFoldMaxLimit or foldAnimTime < self.rotationPart.rotationFoldMinLimit) then
        return false;
    end
    if not self.rotationPart.rotationAllowedIfLowered and self:isLowered() then
        return false
    end
    
    if superFunc ~= nil then
        return superFunc(self);
    end
    return true;
end

function CultiPlough:getIsFoldAllowed(superFunc, onAiTurnOn)
    if self.rotationPart.limitFoldRotationMax ~= nil and self.rotationPart.limitFoldRotationMax == self.rotationMax then
        return false;
    end
    if self.rotationPart.turnAnimation ~= nil and self.getAnimationTime ~= nil then
        local rotationTime = self:getAnimationTime(self.rotationPart.turnAnimation);
        if rotationTime > self.rotationPart.foldRotationMaxLimit or rotationTime < self.rotationPart.foldRotationMinLimit then
            return false;
        end
    end
    if superFunc ~= nil then
        return superFunc(self, onAiTurnOn);
    end
    return true;
end

function CultiPlough:getIsFoldMiddleAllowed(superFunc)
    if self.rotationPart.limitFoldRotationMax ~= nil and self.rotationPart.limitFoldRotationMax == self.rotationMax then
        return false;
    end
    if self.rotationPart.turnAnimation ~= nil and self.getAnimationTime ~= nil then
        local rotationTime = self:getAnimationTime(self.rotationPart.turnAnimation);
        if rotationTime > self.rotationPart.foldRotationMaxLimit or rotationTime < self.rotationPart.foldRotationMinLimit then
            return false;
        end
    end
    if superFunc ~= nil then
        return superFunc(self);
    end
    return true;
end

function CultiPlough:getDirtMultiplier(superFunc)
    local multiplier = 0;
    if superFunc ~= nil then
        multiplier = multiplier + superFunc(self);
    end
    
    if self.ploughHasGroundContact then
        multiplier = multiplier + self.workMultiplier * self:getLastSpeed() / self.speedLimit;
    end
    
    return multiplier;
end

function CultiPlough:loadSpeedRotatingPartFromXML(superFunc, speedRotatingPart, xmlFile, key)
    if superFunc ~= nil then
        if not superFunc(self, speedRotatingPart, xmlFile, key) then
            return false;
        end
    end
    
    speedRotatingPart.disableOnTurn = Utils.getNoNil(getXMLBool(xmlFile, key .. "#disableOnTurn"), true);
    speedRotatingPart.turnAnimLimit = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#turnAnimLimit"), 0);
    speedRotatingPart.turnAnimLimitSide = Utils.getNoNil(getXMLFloat(xmlFile, key .. "#turnAnimLimitSide"), 0);
    speedRotatingPart.invertDirectionOnRotation = Utils.getNoNil(getXMLBool(xmlFile, key .. "#invertDirectionOnRotation"), true);
    
    return true;
end

function CultiPlough:getIsSpeedRotatingPartActive(superFunc, speedRotatingPart)
    if self.rotationPart.turnAnimation ~= nil and speedRotatingPart.disableOnTurn then
        local turnAnimTime = self:getAnimationTime(self.rotationPart.turnAnimation);
        if turnAnimTime ~= nil then
            local enabled = true;
            if speedRotatingPart.turnAnimLimitSide < 0 then
                enabled = (turnAnimTime <= speedRotatingPart.turnAnimLimit);
            elseif speedRotatingPart.turnAnimLimitSide > 0 then
                enabled = (1 - turnAnimTime <= speedRotatingPart.turnAnimLimit);
            else
                enabled = (turnAnimTime <= speedRotatingPart.turnAnimLimit or 1 - turnAnimTime <= speedRotatingPart.turnAnimLimit);
            end
            if not enabled then
                return false;
            end
        end
    end
    
    if superFunc ~= nil then
        return superFunc(self, speedRotatingPart);
    end
    return true;
end

function CultiPlough:getSpeedRotatingPartDirection(superFunc, speedRotatingPart)
    if self.rotationPart.turnAnimation ~= nil then
        local turnAnimTime = self:getAnimationTime(self.rotationPart.turnAnimation);
        if turnAnimTime > 0.5 and speedRotatingPart.invertDirectionOnRotation then
            return -1;
        end
    end
    
    if superFunc ~= nil then
        return superFunc(self, speedRotatingPart);
    end
    return 1;
end

function CultiPlough:doCheckSpeedLimit(superFunc)
    local parent = false;
    if superFunc ~= nil then
        parent = superFunc(self);
    end
    
    return parent or self.isPloughSpeedLimitActive;
end

function CultiPlough:loadWorkAreaFromXML(superFunc, workArea, xmlFile, key)
    local retValue = true;
    if superFunc ~= nil then
        retValue = superFunc(self, workArea, xmlFile, key)
    end
    
    if workArea.type == WorkArea.AREATYPE_DEFAULT then
        workArea.type = WorkArea.AREATYPE_CULTIPLOUGH;
    end
    
    return retValue;
end

function CultiPlough.getDefaultSpeedLimit()
    return 15;
end

function CultiPlough:processPloughAreas(workAreas, limitToField, limitGrassDestructionToField, angle)
    local areaSum = 0;
    for _, area in pairs(workAreas) do
        if self.cultiPloughMode == CultiPlough.MODES.PLOUGH then
            areaSum = areaSum + Utils.updatePloughArea(area[1], area[2], area[3], area[4], area[5], area[6], not limitToField, not limitGrassDestructionToField, angle);
        end
        if self.cultiPloughMode == CultiPlough.MODES.CULTIVATOR then
            areaSum = areaSum + Utils.updateCultivatorArea(area[1], area[2], area[3], area[4], area[5], area[6], not limitToField, not limitGrassDestructionToField, angle);
        end
    end
    return areaSum;
end

function CultiPlough:setCultiPloughMode(mode)
    self.terrainDetailRequiredValueRanges = {};
    self.cultiPloughMode = mode;
    if mode == CultiPlough.MODES.PLOUGH then
        self.typeDesc = g_i18n:getText("typeDesc_plough");
        self.speedLimit = self.ploughSpeedLimit;
        self.powerConsumer.maxForce = self.powerConsumer.ploughMaxForce;
        if self.cp ~= nil then --courseplay workaround
            self.cp.hasSpecializationPlough = true
            self.cp.hasSpecializationCultivator = false
        end
        table.insert(self.terrainDetailRequiredValueRanges, {g_currentMission.cultivatorValue, g_currentMission.cultivatorValue, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels});
        table.insert(self.terrainDetailRequiredValueRanges, {g_currentMission.sowingValue, g_currentMission.sowingValue, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels});
        table.insert(self.terrainDetailRequiredValueRanges, {g_currentMission.sowingWidthValue, g_currentMission.sowingWidthValue, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels});
        table.insert(self.terrainDetailRequiredValueRanges, {g_currentMission.grassValue, g_currentMission.grassValue, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels});
    else
        self.typeDesc = g_i18n:getText("typeDesc_cultivator");
        self.speedLimit = self.cultivatorSpeedLimit;
        self.powerConsumer.maxForce = self.powerConsumer.cultivatorMaxForce;
        if self.cp ~= nil then --courseplay workaround
            self.cp.hasSpecializationPlough = false
            self.cp.hasSpecializationCultivator = true
        end
        table.insert(self.terrainDetailRequiredValueRanges, {g_currentMission.ploughValue, g_currentMission.ploughValue, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels});
        table.insert(self.terrainDetailRequiredValueRanges, {g_currentMission.sowingValue, g_currentMission.sowingValue, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels});
        table.insert(self.terrainDetailRequiredValueRanges, {g_currentMission.sowingWidthValue, g_currentMission.sowingWidthValue, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels});
        table.insert(self.terrainDetailRequiredValueRanges, {g_currentMission.grassValue, g_currentMission.grassValue, g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels});
    end

end
