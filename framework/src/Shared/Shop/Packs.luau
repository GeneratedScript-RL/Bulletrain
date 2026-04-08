--!strict

export type CaseRewardGrant = {
	CaseId: string,
	Amount: number,
}

export type PackReward = {
	Credits: number,
	Cases: { CaseRewardGrant },
}

export type PackOffer = {
	Id: string,
	Name: string,
	RobuxPrice: number,
	DevProductId: number,
	Icon: string,
	Rewards: PackReward,
}

local PACKS: { PackOffer } = {
	{
		Id = "StarterPack",
		Name = "Starter Pack",
		RobuxPrice = 99,
		DevProductId = 0,
		Icon = "",
		Rewards = {
			Credits = 1_500,
			Cases = {
				{ CaseId = "StarterCase", Amount = 2 },
			},
		},
	},
	{
		Id = "TacticalBundle",
		Name = "Tactical Bundle",
		RobuxPrice = 249,
		DevProductId = 0,
		Icon = "",
		Rewards = {
			Credits = 4_500,
			Cases = {
				{ CaseId = "StarterCase", Amount = 3 },
				{ CaseId = "TacticalCase", Amount = 2 },
			},
		},
	},
}

local Packs = {}

local function copyCases(cases: { CaseRewardGrant }): { CaseRewardGrant }
	local out = table.create(#cases)

	for index, caseGrant in ipairs(cases) do
		out[index] = {
			CaseId = caseGrant.CaseId,
			Amount = caseGrant.Amount,
		}
	end

	return out
end

local function copyReward(reward: PackReward): PackReward
	return {
		Credits = reward.Credits,
		Cases = copyCases(reward.Cases),
	}
end

local function copyOffer(offer: PackOffer): PackOffer
	return {
		Id = offer.Id,
		Name = offer.Name,
		RobuxPrice = offer.RobuxPrice,
		DevProductId = offer.DevProductId,
		Icon = offer.Icon,
		Rewards = copyReward(offer.Rewards),
	}
end

function Packs.GetAll(): { PackOffer }
	local out = table.create(#PACKS)

	for index, offer in ipairs(PACKS) do
		out[index] = copyOffer(offer)
	end

	return out
end

function Packs.GetById(packId: string): PackOffer?
	for _, offer in ipairs(PACKS) do
		if offer.Id == packId then
			return copyOffer(offer)
		end
	end

	return nil
end

return Packs
