-- modified version of pokemon lua script provided in mgba example scripts package
-- package.cpath = package.cpath .. ";/Users/kevlamb/.luarocks/lib/lua/5.4/?.so"
json = require "json"
statusString = ""
enemyString = ""
prevEnemyString = ""

all_enemy_ko = false

local Game = {
	new = function (self, game)
		self.__index = self
		setmetatable(game, self)
		return game
	end
}

function Game.getMove(game, moveNumber)
    local pointer = game._movestable + (game._moveslength) * moveNumber
	local allinfo = emu.memory.cart0:read32(pointer)
    local meta = {}
    meta["accuracy"] = allinfo >> 24
    meta["type"] = (allinfo & 0x00FF0000)  >> 16
    meta["bp"] = (allinfo & 0x0000FF00) >> 8
    meta["effect"] = (allinfo & 0x000000FF)
    return meta

end

function Game.getPartyForModel(game)
	local party = {}
	local monStart = game._party
	local nameStart = game._partyNames
	local otStart = game._partyOt
    local partyCount = emu:read8(game._partyCount)
	for i = 1, partyCount do
		local mon = game:_readPartyMon(monStart, nameStart, otStart)
        party[i] = {
            species=mon.species,
            t1=game:getSpeciesType(mon.species)["T1"],
            t2=game:getSpeciesType(mon.species)["T2"],
            hp=mon.hp,
            maxHP=mon.maxHP,
            atk=mon.attack,
            def=mon.defense,
            spa=mon.spAttack,
            spd=mon.spDefense,
            spe=mon.speed,
        }
        party[i].moves = {}
        for j = 1, 4 do
            party[i].moves[j] = {
                acc=game:getMove(mon.moves[j])["accuracy"],
                bp=game:getMove(mon.moves[j])["bp"],
                eff=game:getMove(mon.moves[j])["effect"],
                type=game:getMove(mon.moves[j])["type"]
            }
        end

		monStart = monStart + game._partyMonSize
        if game._partyNames then
			nameStart = nameStart + game._monNameLength + 1
		end
		if game._partyOt then
			otStart = otStart + game._playerNameLength + 1
		end
	end
    -- if we have less than 6 party members, fill the rest of the party with blank party members
    -- so we have a constant number of inputs to the model
    if partyCount == 6 then
        -- full party, no need for further finangling
        return party
    end
    -- not a full party, fill out with nonsense for clean model input
    for i = partyCount+1, 6 do
        -- add nonexistent part member of all 0s
        party[i] = {
            species=0,
            t1=0,
            t2=0,
            hp=0,
            maxHP=0,
            atk=0,
            def=0,
            spa=0,
            spd=0,
            spe=0,
        }
        party[i].moves = {}
        for j = 1, 4 do
            party[i].moves[j] = {
                acc=0,
                bp=0,
                eff=0,
                type=0
            }
        end
    end
	return party
end

function Game.getParty(game)
    local party = {}
	local monStart = game._party
	local nameStart = game._partyNames
	local otStart = game._partyOt
	for i = 1, emu:read8(game._partyCount) do
		party[i] = game:_readPartyMon(monStart, nameStart, otStart)
		monStart = monStart + game._partyMonSize
		if game._partyNames then
			nameStart = nameStart + game._monNameLength + 1
		end
		if game._partyOt then
			otStart = otStart + game._playerNameLength + 1
		end
	end
	return party
end

function Game.getEnemyForModel(game)
	local monStart = game._enemy
	local nameStart = game._enemyNames
	local otStart = game._enemyOt
    local mon = game:_readPartyMon(monStart, nameStart, otStart)
    local enemy = {
        species=mon.species,
        t1=game:getSpeciesType(mon.species)["T1"],
        t2=game:getSpeciesType(mon.species)["T2"],
        hp=mon.hp,
        maxHP=mon.maxHP,
        atk=mon.attack,
        def=mon.defense,
        spa=mon.spAttack,
        spd=mon.spDefense,
        spe=mon.speed,
    }
    return enemy
end

function Game.getEnemy(game)
	local party = {}
	local monStart = game._enemy
	local nameStart = game._enemyNames
	local otStart = game._enemyOt
	for i = 1, 6 do
		party[i] = game:_readPartyMon(monStart, nameStart, otStart)
		monStart = monStart + game._partyMonSize
		if game._partyNames then
			nameStart = nameStart + game._monNameLength + 1
		end
		if game._partyOt then
			otStart = otStart + game._playerNameLength + 1
		end
	end
	return party
end


function Game.toString(game, rawstring)
	local string = ""
	for _, char in ipairs({rawstring:byte(1, #rawstring)}) do
		if char == game._terminator then
			break
		end
		string = string..game._charmap[char]
	end
	return string
end

function Game.getSpeciesName(game, id)
	if game._speciesIndex then
		local index = game._index
		if not index then
			index = {}
			for i = 0, 255 do
				index[emu.memory.cart0:read8(game._speciesIndex + i)] = i
			end
			game._index = index
		end
		id = index[id]
	end
	local pointer = game._speciesNameTable + (game._speciesNameLength) * id
	return game:toString(emu.memory.cart0:readRange(pointer, game._monNameLength))
end

function Game.getSpeciesType(game, id)
    local pointer = game._speciesTable + (game._speciesTableLength) * id
    local lsb = emu.memory.cart0:read32(pointer)
    local msb = emu.memory.cart0:read32(pointer + 4)
    species = {}
    species["T1"] = (msb & 0x00FF0000) >> 16
    species["T2"] = msb >> 24
    return species
end

function Game.getSpeciesInfo(game, id)
    local pointer = game._speciesTable + (game._speciesTableLength) * id
    local lsb = emu.memory.cart0:read32(pointer)
    local msb = emu.memory.cart0:read32(pointer + 4)
    species = {}
    species["bhp"] = lsb & 0x000000FF
    species["batk"] = (lsb & 0x0000FF00) >> 8
    species["bdef"] = (lsb & 0x00FF0000) >> 16
    species["bspe"] = lsb >> 24
    species["bspa"] = msb & 0x000000FF
    species["bspd"] = (msb & 0x0000FF00) >> 8
    species["type1"] = (msb & 0x00FF0000) >> 16
    species["type2"] = msb >> 24
    return printSpeciesType(species)
end

function printSpeciesInfo(species)
    s = ""
    s = s .. string.format("Bhp-%3i Batk-%3i Bdef-%3i Bspe-%3i Bspa-%3i Bspd-%3i T1-%x T2-%x\n",
        species["bhp"],
        species["batk"],
        species["bdef"],
        species["bspe"],
        species["bspa"],
        species["bspd"],
        species["type1"],
        species["type2"])
    return s
end

function printSpeciesType(species)
    s = ""
    s = s .. string.format("T1-%x T2-%x",
        species["type1"],
        species["type2"])
    return s
end


local GBGameEn = Game:new{
	_terminator=0x50,
	_monNameLength=10,
	_speciesNameLength=10,
	_playerNameLength=10,
}

local GBAGameEn = Game:new{
	_terminator=0xFF,
	_monNameLength=10,
	_speciesNameLength=11,
	_playerNameLength=10,
    _moveslength=12,
    _speciesTableLength=28
}

local Generation1En = GBGameEn:new{
	_boxMonSize=33,
	_partyMonSize=44,
}

local Generation2En = GBGameEn:new{
	_boxMonSize=32,
	_partyMonSize=48,
}

local Generation3En = GBAGameEn:new{
	_boxMonSize=80,
	_partyMonSize=100,
}

GBGameEn._charmap = { [0]=
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", " ",
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
	"Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "(", ")", ":", ";", "[", "]",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
	"q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "é", "ʼd", "ʼl", "ʼs", "ʼt", "ʼv",
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�", "�",
	"'", "P\u{200d}k", "M\u{200d}n", "-", "ʼr", "ʼm", "?", "!", ".", "ァ", "ゥ", "ェ", "▹", "▸", "▾", "♂",
	"$", "×", ".", "/", ",", "♀", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
}

GBAGameEn._charmap = { [0]=
	" ", "À", "Á", "Â", "Ç", "È", "É", "Ê", "Ë", "Ì", "こ", "Î", "Ï", "Ò", "Ó", "Ô",
	"Œ", "Ù", "Ú", "Û", "Ñ", "ß", "à", "á", "ね", "ç", "è", "é", "ê", "ë", "ì", "ま",
	"î", "ï", "ò", "ó", "ô", "œ", "ù", "ú", "û", "ñ", "º", "ª", "�", "&", "+", "あ",
	"ぃ", "ぅ", "ぇ", "ぉ", "v", "=", "ょ", "が", "ぎ", "ぐ", "げ", "ご", "ざ", "じ", "ず", "ぜ",
	"ぞ", "だ", "ぢ", "づ", "で", "ど", "ば", "び", "ぶ", "べ", "ぼ", "ぱ", "ぴ", "ぷ", "ぺ", "ぽ",
	"っ", "¿", "¡", "P\u{200d}k", "M\u{200d}n", "P\u{200d}o", "K\u{200d}é", "�", "�", "�", "Í", "%", "(", ")", "セ", "ソ",
	"タ", "チ", "ツ", "テ", "ト", "ナ", "ニ", "ヌ", "â", "ノ", "ハ", "ヒ", "フ", "ヘ", "ホ", "í",
	"ミ", "ム", "メ", "モ", "ヤ", "ユ", "ヨ", "ラ", "リ", "⬆", "⬇", "⬅", "➡", "ヲ", "ン", "ァ",
	"ィ", "ゥ", "ェ", "ォ", "ャ", "ュ", "ョ", "ガ", "ギ", "グ", "ゲ", "ゴ", "ザ", "ジ", "ズ", "ゼ",
	"ゾ", "ダ", "ヂ", "ヅ", "デ", "ド", "バ", "ビ", "ブ", "ベ", "ボ", "パ", "ピ", "プ", "ペ", "ポ",
	"ッ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "!", "?", ".", "-", "・",
	"…", "“", "”", "‘", "’", "♂", "♀", "$", ",", "×", "/", "A", "B", "C", "D", "E",
	"F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U",
	"V", "W", "X", "Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k",
	"l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "▶",
	":", "Ä", "Ö", "Ü", "ä", "ö", "ü", "⬆", "⬇", "⬅", "�", "�", "�", "�", "�", ""
}

function _read16BE(emu, address)
	return (emu:read8(address) << 8) | emu:read8(address + 1)
end

function Generation1En._readBoxMon(game, address, nameAddress, otAddress)
	local mon = {}
	mon.species = emu.memory.cart0:read8(game._speciesIndex + emu:read8(address + 0) - 1)
	mon.hp = _read16BE(emu, address + 1)
	mon.level = emu:read8(address + 3)
	mon.status = emu:read8(address + 4)
	mon.type1 = emu:read8(address + 5)
	mon.type2 = emu:read8(address + 6)
	mon.catchRate = emu:read8(address + 7)
	mon.moves = {
		emu:read8(address + 8),
		emu:read8(address + 9),
		emu:read8(address + 10),
		emu:read8(address + 11),
	}
	mon.otId = _read16BE(emu, address + 12)
	mon.experience = (_read16BE(emu, address + 14) << 8)| emu:read8(address + 16)
	mon.hpEV = _read16BE(emu, address + 17)
	mon.attackEV = _read16BE(emu, address + 19)
	mon.defenseEV = _read16BE(emu, address + 21)
	mon.speedEV = _read16BE(emu, address + 23)
	mon.spAttackEV = _read16BE(emu, address + 25)
	mon.spDefenseEV = mon.spAttackEv
	local iv = _read16BE(emu, address + 27)
	mon.attackIV = (iv >> 4) & 0xF
	mon.defenseIV = iv & 0xF
	mon.speedIV = (iv >> 12) & 0xF
	mon.spAttackIV = (iv >> 8) & 0xF
	mon.spDefenseIV = mon.spAttackIV
	mon.pp = {
		emu:read8(address + 28),
		emu:read8(address + 29),
		emu:read8(address + 30),
		emu:read8(address + 31),
	}
	mon.nickname = game:toString(emu:readRange(nameAddress, game._monNameLength))
	mon.otName = game:toString(emu:readRange(otAddress, game._playerNameLength))
	return mon
end

function Generation1En._readPartyMon(game, address, nameAddress, otAddress)
	local mon = game:_readBoxMon(address, nameAddress, otAddress)
	mon.level = emu:read8(address + 33)
	mon.maxHP = _read16BE(emu, address + 34)
	mon.attack = _read16BE(emu, address + 36)
	mon.defense = _read16BE(emu, address + 38)
	mon.speed = _read16BE(emu, address + 40)
	mon.spAttack = _read16BE(emu, address + 42)
	mon.spDefense = mon.spAttack
	return mon
end

function  Generation2En._readBoxMon(game, address, nameAddress, otAddress)
	local mon = {}
	mon.species = emu:read8(address + 0)
	mon.item = emu:read8(address + 1)
	mon.moves = {
		emu:read8(address + 2),
		emu:read8(address + 3),
		emu:read8(address + 4),
		emu:read8(address + 5),
	}
	mon.otId = _read16BE(emu, address + 6)
	mon.experience = (_read16BE(emu, address + 8) << 8)| emu:read8(address + 10)
	mon.hpEV = _read16BE(emu, address + 11)
	mon.attackEV = _read16BE(emu, address + 13)
	mon.defenseEV = _read16BE(emu, address + 15)
	mon.speedEV = _read16BE(emu, address + 17)
	mon.spAttackEV = _read16BE(emu, address + 19)
	mon.spDefenseEV = mon.spAttackEv
	local iv = _read16BE(emu, address + 21)
	mon.attackIV = (iv >> 4) & 0xF
	mon.defenseIV = iv & 0xF
	mon.speedIV = (iv >> 12) & 0xF
	mon.spAttackIV = (iv >> 8) & 0xF
	mon.spDefenseIV = mon.spAttackIV
	mon.pp = {
		emu:read8(address + 23),
		emu:read8(address + 24),
		emu:read8(address + 25),
		emu:read8(address + 26),
	}
	mon.friendship = emu:read8(address + 27)
	mon.pokerus = emu:read8(address + 28)
	local caughtData = _read16BE(emu, address + 29)
	mon.metLocation = (caughtData >> 8) & 0x7F
	mon.metLevel = caughtData & 0x1F
	mon.level = emu:read8(address + 31)
	mon.nickname = game:toString(emu:readRange(nameAddress, game._monNameLength))
	mon.otName = game:toString(emu:readRange(otAddress, game._playerNameLength))
	return mon
end

function Generation2En._readPartyMon(game, address, nameAddress, otAddress)
	local mon = game:_readBoxMon(address, nameAddress, otAddress)
	mon.status = emu:read8(address + 32)
	mon.hp = _read16BE(emu, address + 34)
	mon.maxHP = _read16BE(emu, address + 36)
	mon.attack = _read16BE(emu, address + 38)
	mon.defense = _read16BE(emu, address + 40)
	mon.speed = _read16BE(emu, address + 42)
	mon.spAttack = _read16BE(emu, address + 44)
	mon.spDefense = _read16BE(emu, address + 46)
	return mon
end

function Generation3En._readBoxMon(game, address)
	local mon = {}
	mon.personality = emu:read32(address + 0)
	mon.otId = emu:read32(address + 4)
	mon.nickname = game:toString(emu:readRange(address + 8, game._monNameLength))
	mon.language = emu:read8(address + 18)
	local flags = emu:read8(address + 19)
	mon.isBadEgg = flags & 1
	mon.hasSpecies = (flags >> 1) & 1
	mon.isEgg = (flags >> 2) & 1
	mon.otName = game:toString(emu:readRange(address + 20, game._playerNameLength))
	mon.markings = emu:read8(address + 27)

	local key = mon.otId ~ mon.personality
	local substructSelector = {
		[ 0] = {0, 1, 2, 3},
		[ 1] = {0, 1, 3, 2},
		[ 2] = {0, 2, 1, 3},
		[ 3] = {0, 3, 1, 2},
		[ 4] = {0, 2, 3, 1},
		[ 5] = {0, 3, 2, 1},
		[ 6] = {1, 0, 2, 3},
		[ 7] = {1, 0, 3, 2},
		[ 8] = {2, 0, 1, 3},
		[ 9] = {3, 0, 1, 2},
		[10] = {2, 0, 3, 1},
		[11] = {3, 0, 2, 1},
		[12] = {1, 2, 0, 3},
		[13] = {1, 3, 0, 2},
		[14] = {2, 1, 0, 3},
		[15] = {3, 1, 0, 2},
		[16] = {2, 3, 0, 1},
		[17] = {3, 2, 0, 1},
		[18] = {1, 2, 3, 0},
		[19] = {1, 3, 2, 0},
		[20] = {2, 1, 3, 0},
		[21] = {3, 1, 2, 0},
		[22] = {2, 3, 1, 0},
		[23] = {3, 2, 1, 0},
	}

	local pSel = substructSelector[mon.personality % 24]
	local ss0 = {}
	local ss1 = {}
	local ss2 = {}
	local ss3 = {}

	for i = 0, 2 do
		ss0[i] = emu:read32(address + 32 + pSel[1] * 12 + i * 4) ~ key
		ss1[i] = emu:read32(address + 32 + pSel[2] * 12 + i * 4) ~ key
		ss2[i] = emu:read32(address + 32 + pSel[3] * 12 + i * 4) ~ key
		ss3[i] = emu:read32(address + 32 + pSel[4] * 12 + i * 4) ~ key
	end

	mon.species = ss0[0] & 0xFFFF
	mon.heldItem = ss0[0] >> 16
	mon.experience = ss0[1]
	mon.ppBonuses = ss0[2] & 0xFF
	mon.friendship = (ss0[2] >> 8) & 0xFF

	mon.moves = {
		ss1[0] & 0xFFFF,
		ss1[0] >> 16,
		ss1[1] & 0xFFFF,
		ss1[1] >> 16
	}
	mon.pp = {
		ss1[2] & 0xFF,
		(ss1[2] >> 8) & 0xFF,
		(ss1[2] >> 16) & 0xFF,
		ss1[2] >> 24
	}

	mon.hpEV = ss2[0] & 0xFF
	mon.attackEV = (ss2[0] >> 8) & 0xFF
	mon.defenseEV = (ss2[0] >> 16) & 0xFF
	mon.speedEV = ss2[0] >> 24
	mon.spAttackEV = ss2[1] & 0xFF
	mon.spDefenseEV = (ss2[1] >> 8) & 0xFF
	mon.cool = (ss2[1] >> 16) & 0xFF
	mon.beauty = ss2[1] >> 24
	mon.cute = ss2[2] & 0xFF
	mon.smart = (ss2[2] >> 8) & 0xFF
	mon.tough = (ss2[2] >> 16) & 0xFF
	mon.sheen = ss2[2] >> 24

	mon.pokerus = ss3[0] & 0xFF
	mon.metLocation = (ss3[0] >> 8) & 0xFF
	flags = ss3[0] >> 16
	mon.metLevel = flags & 0x7F
	mon.metGame = (flags >> 7) & 0xF
	mon.pokeball = (flags >> 11) & 0xF
	mon.otGender = (flags >> 15) & 0x1
	flags = ss3[1]
	mon.hpIV = flags & 0x1F
	mon.attackIV = (flags >> 5) & 0x1F
	mon.defenseIV = (flags >> 10) & 0x1F
	mon.speedIV = (flags >> 15) & 0x1F
	mon.spAttackIV = (flags >> 20) & 0x1F
	mon.spDefenseIV = (flags >> 25) & 0x1F
	-- Bit 30 is another "isEgg" bit
	mon.altAbility = (flags >> 31) & 1
	flags = ss3[2]
	mon.coolRibbon = flags & 7
	mon.beautyRibbon = (flags >> 3) & 7
	mon.cuteRibbon = (flags >> 6) & 7
	mon.smartRibbon = (flags >> 9) & 7
	mon.toughRibbon = (flags >> 12) & 7
	mon.championRibbon = (flags >> 15) & 1
	mon.winningRibbon = (flags >> 16) & 1
	mon.victoryRibbon = (flags >> 17) & 1
	mon.artistRibbon = (flags >> 18) & 1
	mon.effortRibbon = (flags >> 19) & 1
	mon.marineRibbon = (flags >> 20) & 1
	mon.landRibbon = (flags >> 21) & 1
	mon.skyRibbon = (flags >> 22) & 1
	mon.countryRibbon = (flags >> 23) & 1
	mon.nationalRibbon = (flags >> 24) & 1
	mon.earthRibbon = (flags >> 25) & 1
	mon.worldRibbon = (flags >> 26) & 1
	mon.eventLegal = (flags >> 27) & 0x1F
	return mon
end

function Generation3En._readPartyMon(game, address)
	local mon = game:_readBoxMon(address)
	mon.status = emu:read32(address + 80)
	mon.level = emu:read8(address + 84)
	mon.mail = emu:read32(address + 85)
	mon.hp = emu:read16(address + 86)
	mon.maxHP = emu:read16(address + 88)
	mon.attack = emu:read16(address + 90)
	mon.defense = emu:read16(address + 92)
	mon.speed = emu:read16(address + 94)
	mon.spAttack = emu:read16(address + 96)
	mon.spDefense = emu:read16(address + 98)
	return mon
end

local gameRBEn = Generation1En:new{
	name="Red/Blue (USA)",
	_party=0xd16b,
	_partyCount=0xd163,
	_partyNames=0xd2b5,
	_partyOt=0xd273,
	_speciesNameTable=0x1c21e,
	_speciesIndex=0x41024,
}

local gameYellowEn = Generation1En:new{
	name="Yellow (USA)",
	_party=0xd16a,
	_partyCount=0xd162,
	_partyNames=0xd2b4,
	_partyOt=0xd272,
	_speciesNameTable=0xe8000,
	_speciesIndex=0x410b1,
}

local gameGSEn = Generation2En:new{
	name="Gold/Silver (USA)",
	_party=0xda2a,
	_partyCount=0xda22,
	_partyNames=0xdb8c,
	_partyOt=0xdb4a,
	_speciesNameTable=0x1b0b6a,
}

local gameCrystalEn = Generation2En:new{
	name="Crystal (USA)",
	_party=0xdcdf,
	_partyCount=0xdcd7,
	_partyNames=0xde41,
	_partyOt=0xddff,
	_speciesNameTable=0x5337a,
}

local gameRubyEn = Generation3En:new{
	name="Ruby (USA)",
	_party=0x3004360,
	_partyCount=0x3004350,
	_speciesNameTable=0x1f716c,
}

local gameRubyEnR1 = Generation3En:new{
	name="Ruby (USA)",
	_party=0x3004360,
	_partyCount=0x3004350,
	_speciesNameTable=0x1f7184,
}

local gameSapphireEn = Generation3En:new{
	name="Sapphire (USA)",
	_party=0x3004360,
	_partyCount=0x3004350,
	_speciesNameTable=0x1f70fc,
}

local gameSapphireEnR1 = Generation3En:new{
	name="Sapphire (USA)",
	_party=0x3004360,
	_partyCount=0x3004350,
	_speciesNameTable=0x1f7114,
}

local gameEmeraldEn = Generation3En:new{
	name="Emerald (USA)",
	_party=0x20244ec,
	_partyCount=0x20244e9,
	_speciesNameTable=0x3185c8,
    _enemy=0x2024744,
    _enemyCount=0x2024741,
    _movestable=0x0831C898,
    _speciesTable=0x083203E8 
    
}

local gameFireRedEn = Generation3En:new{
	name="FireRed (USA)",
	_party=0x2024284,
	_partyCount=0x2024029,
	_speciesNameTable=0x245ee0,
}

local gameFireRedEnR1 = gameFireRedEn:new{
	name="FireRed (USA) (Rev 1)",
	_speciesNameTable=0x245f50,
}

local gameLeafGreenEn = Generation3En:new{
	name="LeafGreen (USA)",
	_party=0x2024284,
	_partyCount=0x2024029,
	_speciesNameTable=0x245ebc,
}

local gameLeafGreenEnR1 = gameLeafGreenEn:new{
	name="LeafGreen (USA)",
	_party=0x2024284,
	_partyCount=0x2024029,
	_speciesNameTable=0x245f2c,
}

gameCodes = {
	["DMG-AAUE"]=gameGSEn, -- Gold
	["DMG-AAXE"]=gameGSEn, -- Silver
	["CGB-BYTE"]=gameCrystalEn,
	["AGB-AXVE"]=gameRubyEn,
	["AGB-AXPE"]=gameSapphireEn,
	["AGB-BPEE"]=gameEmeraldEn,
	["AGB-BPRE"]=gameFireRedEn,
	["AGB-BPGE"]=gameLeafGreenEn,
}

-- These versions have slight differences and/or cannot be uniquely
-- identified by their in-header game codes, so fall back on a CRC32
gameCrc32 = {
	[0x9f7fdd53] = gameRBEn, -- Red
	[0xd6da8a1a] = gameRBEn, -- Blue
	[0x7d527d62] = gameYellowEn,
	[0x84ee4776] = gameFireRedEnR1,
	[0xdaffecec] = gameLeafGreenEnR1,
	[0x61641576] = gameRubyEnR1, -- Rev 1
	[0xaeac73e6] = gameRubyEnR1, -- Rev 2
	[0xbafedae5] = gameSapphireEnR1, -- Rev 1
	[0x9cc4410e] = gameSapphireEnR1, -- Rev 2
}

function printPartyStatus(game, buffer)
	buffer:clear()
	for _, mon in ipairs(game:getParty()) do
		buffer:print(string.format("%-10s (Lv%3i %10s): %3i/%3i\nAtk:%3i\nDef%3i\nSpA%3i\nSpD%3i\nSpe%3i\nMove1: Acc-%x BP-%x Eff-%x Type-%x \nMove2: Acc-%x BP-%x Eff-%x Type-%x \nMove3: Acc-%x BP-%x Eff-%x Type-%x \nMove4: Acc-%x BP-%x Eff-%x Type-%x",
        mon.nickname,
        mon.level,
        game:getSpeciesName(mon.species),
        mon.hp,
        mon.maxHP,
        mon.attack,
        mon.defense,
        mon.spAttack,
        mon.spDefense,
        mon.speed,
        game:getMove(mon.moves[1])["accuracy"],
        game:getMove(mon.moves[1])["bp"],
        game:getMove(mon.moves[1])["effect"],
        game:getMove(mon.moves[1])["type"],
        game:getMove(mon.moves[2])["accuracy"],
        game:getMove(mon.moves[2])["bp"],
        game:getMove(mon.moves[2])["effect"],
        game:getMove(mon.moves[2])["type"],
        game:getMove(mon.moves[3])["accuracy"],
        game:getMove(mon.moves[3])["bp"],
        game:getMove(mon.moves[3])["effect"],
        game:getMove(mon.moves[3])["type"],
        game:getMove(mon.moves[4])["accuracy"],
        game:getMove(mon.moves[4])["bp"],
        game:getMove(mon.moves[4])["effect"],
        game:getMove(mon.moves[4])["type"]))
        -- buffer:print(mon.moves)
	end
end

function battledata(game)
    data = ""
    for _, mon in ipairs(game:getParty()) do
		data = data .. string.format("(%10s %s): %3i/%3i\nAtk:%3i\nDef%3i\nSpA%3i\nSpD%3i\nSpe%3i\n",
        game:getSpeciesName(mon.species),
        game:getSpeciesInfo(mon.species),
        mon.hp,
        mon.maxHP,
        mon.attack,
        mon.defense,
        mon.spAttack,
        mon.spDefense,
        mon.speed)

        for i = 1, 4 do
            data = data .. string.format("Move %1i: Acc-%x BP-%x Eff-%x Type-%x \n",
            i,
            game:getMove(mon.moves[i])["accuracy"],
            game:getMove(mon.moves[i])["bp"],
            game:getMove(mon.moves[i])["effect"],
            game:getMove(mon.moves[i])["type"])
        end
        data = data .. mon
	end
    return data
end

function partyStatus(game)
    -- party = ""
    -- for _, mon in ipairs(game:getParty()) do
	-- 	party = party .. string.format("%-10s (Lv%3i %10s): %3i/%3i\nAtk:%3i\nDef%3i\nSpA%3i\nSpD%3i\nSpe%3i\nM1: %10s",
    --     mon.nickname,
    --     mon.level,
    --     game:getSpeciesName(mon.species),
    --     mon.hp,
    --     mon.maxHP,
    --     mon.attack,
    --     mon.defense,
    --     mon.spAttack,
    --     mon.spDefense,
    --     mon.speed,
    --     mon.moves)
	-- end
    -- return party
    return json.encode(game:getPartyForModel())
end

function enemyStatus(game)
    data = ""
    for _, mon in ipairs(game:getEnemy()) do
	 	data = data .. string.format("(%10s %s): %3i/%3i\nAtk:%3i\nDef%3i\nSpA%3i\nSpD%3i\nSpe%3i\n",
    		game:getSpeciesName(mon.species),
        	game:getSpeciesInfo(mon.species),
        	mon.hp,
        	mon.maxHP,
        	mon.attack,
        	mon.defense,
        	mon.spAttack,
        	mon.spDefense,
        	mon.speed)

    end

	all_enemy_ko = ((tonumber(game:getEnemy()[1].hp)) == 0) and ((tonumber(game:getEnemy()[2].hp)) == 0) and ((tonumber(game:getEnemy()[3].hp)) == 0) and ((tonumber(game:getEnemy()[4].hp)) == 0) and ((tonumber(game:getEnemy()[5].hp)) == 0) and ((tonumber(game:getEnemy()[6].hp)) == 0)

    --mon = game:getEnemy()[1]
    --data = data .. string.format("(%10s %s): %3i/%3i\nAtk:%3i\nDef%3i\nSpA%3i\nSpD%3i\nSpe%3i\n",
    --    game:getSpeciesName(mon.species),
    --    game:getSpeciesInfo(mon.species),
    --    mon.hp,
    --    mon.maxHP,
    --    mon.attack,
    --   mon.defense,
    --    mon.spAttack,
    --    mon.spDefense,
     --   mon.speed)
    return data
end

function won_battle_check(game)
    all_enemy_ko = ((tonumber(game:getEnemy()[1].hp)) == 0) and ((tonumber(game:getEnemy()[2].hp)) == 0) and ((tonumber(game:getEnemy()[3].hp)) == 0) and ((tonumber(game:getEnemy()[4].hp)) == 0) and ((tonumber(game:getEnemy()[5].hp)) == 0) and ((tonumber(game:getEnemy()[6].hp)) == 0)
end

function battleStatus(game)
    local status = {
        Mode="Battle",
        Data={
            Party=game:getPartyForModel(),
            Enemy=game:getEnemyForModel()
        }
    }
    return json.encode(status)
end


function detectGame()
	local checksum = 0
	for i, v in ipairs({emu:checksum(C.CHECKSUM.CRC32):byte(1, 4)}) do
		checksum = checksum * 256 + v
	end
	game = gameCrc32[checksum]
	if not game then
		game = gameCodes[emu:getGameCode()]
	end

	if not game then
		console:error("Unknown game!")
	else
		console:log("Found game: " .. game.name)
		if not partyBuffer then
			partyBuffer = console:createBuffer("Party")
		end
	end
end

function updateBuffer()
	if not game or not partyBuffer then
		return
	end
	printPartyStatus(game, partyBuffer)
end

function sendParty()
    if not game then
        return
    end
    -- statusString = battledata(game)
    -- won_battle_check(game)
    statusString = battleStatus(game)
    -- statusString = partyStatus(game)
	prevEnemyString = enemyString -- Before updating the enemy string, store the current one
    enemyString = enemyStatus(game)
end

-- Events.Connect("getParty", sendParty)

callbacks:add("start", detectGame)
callbacks:add("frame", sendParty)
-- callbacks:add("frame", updateBuffer)
if emu then
	detectGame()
end