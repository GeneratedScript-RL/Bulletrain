--!strict

export type CoinOffer = {
	Id: string,
	Coins: number,
	RobuxPrice: number,
	DevProductId: number,
	Icon: string,
	BonusText: string?,
}

local OFFERS: { CoinOffer } = {
	{
		Id = "SmallCoins",
		Coins = 500,
		RobuxPrice = 49,
		DevProductId = 0,
		Icon = "",
	},
	{
		Id = "MediumCoins",
		Coins = 1_500,
		RobuxPrice = 129,
		DevProductId = 0,
		Icon = "",
		BonusText = "+25% MORE",
	},
	{
		Id = "LargeCoins",
		Coins = 4_000,
		RobuxPrice = 299,
		DevProductId = 0,
		Icon = "",
		BonusText = "+50% MORE",
	},
	{
		Id = "HugeCoins",
		Coins = 9_000,
		RobuxPrice = 599,
		DevProductId = 0,
		Icon = "",
		BonusText = "+100% MORE",
	},
	{
		Id = "MegaCoins",
		Coins = 20_000,
		RobuxPrice = 999,
		DevProductId = 0,
		Icon = "",
		BonusText = "+150% MORE",
	},
}

local CoinProducts = {}

local function copyOffer(offer: CoinOffer): CoinOffer
	return {
		Id = offer.Id,
		Coins = offer.Coins,
		RobuxPrice = offer.RobuxPrice,
		DevProductId = offer.DevProductId,
		Icon = offer.Icon,
		BonusText = offer.BonusText,
	}
end

function CoinProducts.GetAll(): { CoinOffer }
	local out = table.create(#OFFERS)

	for index, offer in ipairs(OFFERS) do
		out[index] = copyOffer(offer)
	end

	return out
end

function CoinProducts.GetById(offerId: string): CoinOffer?
	for _, offer in ipairs(OFFERS) do
		if offer.Id == offerId then
			return copyOffer(offer)
		end
	end

	return nil
end

return CoinProducts
