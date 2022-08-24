if not shared.PerthCombatBot then
    shared.PerthCombatBot = {
        Signals = {};
        Looped = false;
    }
end

local BlacklistItems = {
    "1";
    "2";
    "3";
    "4";
    "5";
    "6";
    "7";
    "8";
    "9";
    "30";
}

local PerthCombatBot = shared.PerthCombatBot

PerthCombatBot.FoundDecision = false;

--print ("  "):rep(100)

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer;

local Backpack = LocalPlayer.Backpack;
local PlayerGui = LocalPlayer.PlayerGui;

local Character, HumanoidRootPart, Head = nil;

local Sort = loadstring(game:HttpGet('https://raw.githubusercontent.com/Perthys/SmartSort/main/main.lua'))()
local DumpTable = loadstring(game:HttpGet("https://raw.githubusercontent.com/strawbberrys/LuaScripts/main/TableDumper.lua"))()

local OldPrint = print; print = function(...) OldPrint("PerthCombat | ", ...) end

local Algorithims = {
    ["PlayerDefault"] = Sort.new()
        :Add("Health", 1, "Higher")
        :Add("Distance", 2, "Higher")
        :Add("Facing", 5, "Lower")
        :Add("IsBlack", 5, "Lower")
}

local function DefineVariables()
    Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait();
    HumanoidRootPart = Character:WaitForChild("HumanoidRootPart");
    Head = Character:WaitForChild("Head");
end

local function AddSignal(Arg)
    table.insert(shared.PerthCombatBot.Signals, Arg)
end

local function FlushSignals()
    if shared.PerthCombatBot.Signals then
        for Index, Signals in pairs(shared.PerthCombatBot.Signals) do
            Signals:Disconnect()
        end
    end
end

DefineVariables()
FlushSignals()

AddSignal(LocalPlayer.CharacterAdded:Connect(function()
    DefineVariables()
    print("Respawned")
end))

local PositionMap = nil;

PositionMap = {
    ["CFrame"] = function(Arg)
        return Arg.Position
    end;
    ["Vector3"] = function(Arg)
        return Arg
    end;
    ["Instance"] = function(Arg)
        for Index, Value in pairs(PositionMap.__InstanceMap) do
            if Arg:IsA(Index) then
                return Value(Arg);
            end
        end
    end;
    __InstanceMap = {
        ["PVInstance"] = function(Arg)
            return Arg:GetPivot().Position;
        end;
        ["Player"] = function(Arg) 
            local Character = Arg.Character or Arg.CharacterAdded:Wait();
            
            if Character then
                return Character:GetPivot().Position;
            end
        end;
        ["Humanoid"] = function(Arg)
            local Character = Arg.Parent;
            
            if Character then
                return Character:GetPivot().Position;
            end
        end
    };
}

local function ConverToPosition(Arg1)
    return PositionMap[typeof(Arg1)](Arg1);
end

local function GetMagnitude(Arg1, Arg2)
    local ReturnedData1 = PositionMap[typeof(Arg1)];
    local ReturnedData2 = PositionMap[typeof(Arg2)];
    
    if ReturnedData1 and ReturnedData2 then
        ReturnedData1 = ReturnedData1(Arg1);
        ReturnedData2 = ReturnedData2(Arg2)
        
        return (ReturnedData1 - ReturnedData2).Magnitude;
    end
end

local function CheckLookAt(LookingAt, LookedAt)
    local LookingAtToLookedAt = (LookedAt.Position - LookingAt.Position).Unit;
    local LookingAtVector = LookingAt.CFrame.LookVector;
 
    local DotProduct = LookingAtToLookedAt:Dot(LookingAtVector);
    
    return DotProduct
end
local function LookAt(Part1, PositionArg) 
    PositionArg = ConverToPosition(PositionArg)
  --  Part1.CFrame = CFrame.lookAt(Part1.Position, PositionArg, Vector3.new(Part1.Position.X, PositionArg.Y, Part1.Position.Z))

    Part1:PivotTo(CFrame.new(Part1.Position, Vector3.new(PositionArg.X, Part1.Position.Y, PositionArg.Z)))
end

local function FindBestTargetsRelativeTo(RelativeCharacter, CheckTeam, Verification, CustomGetterFunction)
    local PossibleTargets = {}
    
    Verification = Verification or function()
        return true
    end
    
    local HumanoidRootPart = RelativeCharacter:FindFirstChild("HumanoidRootPart");
    local Head = RelativeCharacter:FindFirstChild("Head");
        
    if HumanoidRootPart and Head then
        if not CustomGetterFunction then
            for Index, Player in pairs(Players:GetPlayers()) do
                if Player ~= LocalPlayer then
                    if CheckTeam and Player.Team == LocalPlayer.Team then
                        continue;
                    end
                    
                    if not Verification(Player) then
                        continue;
                    end
                    
                    local OtherCharacter = Player.Character;
                    
                    if OtherCharacter then
                        local OtherHumanoidRootPart = OtherCharacter:FindFirstChild("HumanoidRootPart");
                        local OtherHumanoid = OtherCharacter:FindFirstChild("Humanoid");
                        
                        local OtherHead = OtherCharacter:FindFirstChild("Head")
                        
                        if OtherHumanoidRootPart and OtherHumanoid and OtherHead and OtherHumanoid.Health >= 1 and OtherHumanoidRootPart.Position.Y >= 10 then
                            table.insert(PossibleTargets, {
                                Player = Player;
                                Distance = GetMagnitude(HumanoidRootPart, OtherHumanoidRootPart);
                                Health = OtherHumanoid.Health;
                                Facing = CheckLookAt(OtherHead, Head);
                            })
                        end
                    end
                end
            end
        elseif CustomGetterFunction then
            PossibleTargets = CustomGetterFunction();
        end
        
        return Algorithims.PlayerDefault:Sort(PossibleTargets)
    end
end

local CheckSightActions = {}

local function Raycast(StartPosition, EndPosition, RaycastParams)
    local Expression = (StartPosition - EndPosition);
    
    if StartPosition and EndPosition and RaycastParams then
        local a = workspace:Raycast(StartPosition, Expression.Unit * Expression.Magnitude, RaycastParams)
        
        return a
    end
end

local IgnoreList = {}

local function CheckSight(Arg1, Arg2)
	local RaycastParams = RaycastParams.new() do
        RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        
        table.insert(IgnoreList, Arg1)
        RaycastParams.FilterDescendantsInstances = IgnoreList
        RaycastParams.IgnoreWater = true
	end
	
    local Arg1Position = ConverToPosition(Arg1)
    local Arg2Position = ConverToPosition(Arg2);
    
    if Arg1Position and Arg2Position then
        local RaycastResult = Raycast(Arg1Position, Arg2Position, RaycastParams);
        
        table.remove(IgnoreList, table.find(IgnoreList, Arg1))
        if RaycastResult then
            local Instance = RaycastResult.Instance;
            
            if Instance:IsDescendantOf(Arg2) then
                return true
            end
            
            return false
        elseif not RaycastResult then
            return true
        end
    end
end

local Decisions = {
    ["Approach"] = function(Character, TargetCharacter)
        local Humanoid = Character:FindFirstChild("Humanoid")
        local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
        
        local TargetHumanoid = TargetCharacter:FindFirstChild("Humanoid");
        
        local TargetHumanoidRootPart = TargetCharacter:FindFirstChild("HumanoidRootPart")
        
        local Position = ConverToPosition(TargetHumanoid)
        
        if Humanoid and TargetHumanoid then
            LookAt(HumanoidRootPart, Position)
            Humanoid:MoveTo((TargetHumanoidRootPart.CFrame * CFrame.new(math.random(-2, 2),0,-2)).Position)
    
            local ReferLater; ReferLater = TargetHumanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
                ReferLater:Disconnect();
                PerthCombatBot.FoundDecision = false;
            end)
            
            local ReferLater; ReferLater = Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
                ReferLater:Disconnect();
                PerthCombatBot.FoundDecision = false;
            end)
                
            Humanoid.MoveToFinished:Wait();
            
            Humanoid:MoveTo((TargetHumanoidRootPart.CFrame * CFrame.new(-math.random(-2, 2),0,2)).Position)
        end
        
        PerthCombatBot.FoundDecision = false;
    end;
    ["PathFind"] = function(Humanoid, TargetPart)
        local Path = PathfindingService:CreatePath({
            ["AgentCanJump"] = true;
            ["Costs"] = {
		        Water = 20
        	}
        });
        
        PerthCombatBot.FoundDecision = false;
    end;
    ["Escape"] = function(Character, TargetCharacter)
        local Humanoid = Character:FindFirstChild("Humanoid");
        local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart");
        local TargetHumanoidRootPart = TargetCharacter:FindFirstChild("HumanoidRootPart")
        
        Humanoid.AutoRotate = false;
        
        if GetMagnitude(HumanoidRootPart, TargetHumanoidRootPart) < 2 then
            --LookAt(TargetHumanoidRootPart, HumanoidRootPart)
            Humanoid:MoveTo(HumanoidRootPart.CFrame * CFrame.new(0, 0, 10).Position)
        end
        
        PerthCombatBot.FoundDecision = false;
    end;
}

local HitDebounce = false;

local Conditons = {
    [-2] = function(Character, TargetCharacter) 
        for Index, Value in pairs(workspace:GetPartBoundsInRadius(Character:GetPivot().Position, 10)) do
            if table.find(BlacklistItems, Value.Name) or ReplicatedStorage:FindFirstChild(Value.Name) then
                local Humanoid = Character:FindFirstChild("Humanoid")
                
                print("Found Avoiding")
                if Humanoid then
                    local Ran = math.random(1,2) == 1 and 10 or -10
                    
                    Humanoid:MoveTo(Value.CFrame * CFrame.new(0, 0, Ran).Position)
                    Humanoid.Jump = true
                end
            end
        end
    end,
    [-1] = function(Character, TargetCharacter)
        if Character:GetPivot().Position.Y < TargetCharacter:GetPivot().Position.Y then
            local Humanoid = Character:FindFirstChild("Humanoid")
            
            if Humanoid then
                Humanoid.Jump = true;
            end
        end
    end;
    [0] = function(Character, TargetCharacter)
        local Portal = workspace.Portal
        if (Portal.Position - Character:GetPivot().Position).Magnitude <= 50 then
            Character:PivotTo(Portal.CFrame)
        end
    end;
    [1] = function(Character, TargetCharacter) -- RunAwayMode
        local Humanoid = Character:FindFirstChild("Humanoid");
        local TargetHumanoid = TargetCharacter:FindFirstChild("Humanoid")
        
        PerthCombatBot.FoundDecision = true;
        Decisions.Escape(Character, TargetCharacter);
        
        if Humanoid.Health < Humanoid.Health * 0.5 then
            Decisions.Escape(Character, TargetCharacter)
        end
        
    end;
    [2] = function(Character, TargetCharacter) -- AttackMode
        if (TargetCharacter:GetPivot().Position - Character:GetPivot().Position).Magnitude <= 8 and not HitDebounce then
            HitDebounce = true
            local AbilitiesEvent = Character:FindFirstChild("AbilitiesEvent");
            local HitEvent = Character:FindFirstChild("HitEvent");
            local TargetHumanoid = TargetCharacter:FindFirstChild("Humanoid")
            local TargetHumanoidRootPart = TargetCharacter:FindFirstChild("HumanoidRootPart")
            
            if AbilitiesEvent and HitEvent and TargetHumanoid and TargetHumanoidRootPart then
                AbilitiesEvent:FireServer(Enum.KeyCode.Unknown, Enum.UserInputType.MouseButton1)
                HitEvent:FireServer(TargetHumanoid, 0, 1.8, TargetHumanoidRootPart.Position)
            end
            
            task.delay(0.20, function()
                HitDebounce = false
            end)
        end
    end;
    [3] = function(Character, TargetCharacter) -- ShouldApproach
        local Head = Character:FindFirstChild("Head");
        local TargetHead = TargetCharacter:FindFirstChild("Head")
            
        local Humanoid = Character:FindFirstChild("Humanoid");

        if Head and TargetHead and Humanoid and TargetHead.Position ~= Head.Position then
            if CheckSight(Head, TargetHead) then
                PerthCombatBot.FoundDecision = true;
                return Decisions.Approach(Character, TargetCharacter);
            elseif not CheckSight(Head, TargetHead) then
                PerthCombatBot.FoundDecision = true;
                return Decisions.PathFind(Character, TargetCharacter);
            end
        end

        return false;
    end;
}

local function FindBestDecisions(Character, TargetCharacter)
    if not PerthCombatBot.FoundDecision then
        for Index, Value in pairs(Conditons) do
            Value(Character, TargetCharacter)
            if FoundDecision then
                print(Index, Value)
                return Index
            end
        end
    end
end

local OldBestTarget = nil;

local function Main()
    local Targets = FindBestTargetsRelativeTo(Character, false, function()
        return true
    end)
    
    if Targets and #Targets >= 1 then
        
        local BestTarget = Targets[1];
        
        if OldBestTarget ~= BestTarget then
            PerthCombatBot.FoundDecision = false;
        end
        
        OldBestTarget = BestTarget;
        
        LookAt(HumanoidRootPart, BestTarget.Player.Character.HumanoidRootPart)
        
        if BestTarget.Player then
            task.spawn(function()
                FindBestDecisions(Character, BestTarget.Player.Character)
            end)
        end
    end
end

PerthCombatBot.Looped = false
PerthCombatBot.Looped = true;

while PerthCombatBot.Looped do
   -- print("FoundDecision: "..tostring(PerthCombatBot.FoundDecision))
    Main()
    
    wait()
end
