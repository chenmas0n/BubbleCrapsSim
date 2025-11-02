extends Node
# Autoload singleton for managing powerups

# ============================================
# POWERUP TYPES
# ============================================
enum PowerupType {
	GOLDEN_DICE,        # +25% all payouts
	EXTRA_CHANCES,      # +3 rolls per level
	LUCKY_NUMBER,       # 2x payout on one chosen number
	SEVEN_SHIELD,       # First 7 per level doesn't lose wagers
	DEEP_POCKETS,       # +500 starting points per level
	SECOND_CHANCE,      # One reroll per level
	INSURANCE_POLICY,   # Get 50% wagers back when rolling 7
	HOT_STREAK,         # 3 consecutive wins = +1000 bonus
	JACKPOT,            # Rolling 2 or 12 pays 3x normal
	RISK_TAKER          # +50% payouts but lose 1.5x on 7
}

# ============================================
# POWERUP DATABASE
# ============================================
const POWERUP_DATA := {
	PowerupType.GOLDEN_DICE: {
		"name": "Golden Dice",
		"description": "All payouts increased by 25%",
		"rarity": "common"
	},
	PowerupType.EXTRA_CHANCES: {
		"name": "Extra Chances",
		"description": "Start each level with +3 rolls",
		"rarity": "common"
	},
	PowerupType.LUCKY_NUMBER: {
		"name": "Lucky Number",
		"description": "Choose one number - it pays 2x",
		"rarity": "rare"
	},
	PowerupType.SEVEN_SHIELD: {
		"name": "Seven Shield",
		"description": "First 7 each level doesn't lose wagers",
		"rarity": "rare"
	},
	PowerupType.DEEP_POCKETS: {
		"name": "Deep Pockets",
		"description": "Start each level with +500 points",
		"rarity": "common"
	},
	PowerupType.SECOND_CHANCE: {
		"name": "Second Chance",
		"description": "Reroll once per level",
		"rarity": "rare"
	},
	PowerupType.INSURANCE_POLICY: {
		"name": "Insurance Policy",
		"description": "Get 50% of wagers back when rolling 7",
		"rarity": "common"
	},
	PowerupType.HOT_STREAK: {
		"name": "Hot Streak",
		"description": "Win 3 in a row for +1000 bonus",
		"rarity": "rare"
	},
	PowerupType.JACKPOT: {
		"name": "Jackpot",
		"description": "Rolling 2 or 12 pays 3x normal",
		"rarity": "legendary"
	},
	PowerupType.RISK_TAKER: {
		"name": "Risk Taker",
		"description": "+50% payouts, but lose 1.5x on 7",
		"rarity": "legendary"
	}
}

# ============================================
# STATE VARIABLES
# ============================================
var active_powerups := []      # Array of active PowerupType enums
var powerup_data := {}         # Extra data (e.g., lucky number = 7)
var seven_shield_used := false # Track if shield was used this level
var reroll_used := false       # Track if reroll was used this level
var win_streak := 0            # Track consecutive wins for Hot Streak

# ============================================
# CORE FUNCTIONS
# ============================================

func add_powerup(type: PowerupType, data = null) -> void:
	active_powerups.append(type)
	if data:
		powerup_data[type] = data
	print("[PowerupManager] Added: ", POWERUP_DATA[type]["name"])

func has_powerup(type: PowerupType) -> bool:
	return type in active_powerups

func reset_powerups() -> void:
	active_powerups.clear()
	powerup_data.clear()
	seven_shield_used = false
	reroll_used = false
	win_streak = 0
	print("[PowerupManager] All powerups reset")

func reset_level_powerups() -> void:
	# Reset per-level flags when starting new level
	seven_shield_used = false
	reroll_used = false

# ============================================
# PAYOUT MODIFIERS
# ============================================

func apply_payout_modifiers(base_payout: int, number: int) -> int:
	var modified = base_payout
	
	# Golden Dice: +25%
	if has_powerup(PowerupType.GOLDEN_DICE):
		modified = int(modified * 1.25)
	
	# Lucky Number: 2x on specific number
	if has_powerup(PowerupType.LUCKY_NUMBER):
		var lucky_num = powerup_data.get(PowerupType.LUCKY_NUMBER, -1)
		if lucky_num == number:
			modified *= 2
	
	# Jackpot: 3x on 2 or 12
	if has_powerup(PowerupType.JACKPOT):
		if number == 2 or number == 12:
			modified *= 3
	
	# Risk Taker: +50% all payouts
	if has_powerup(PowerupType.RISK_TAKER):
		modified = int(modified * 1.5)
	
	return modified

# ============================================
# SEVEN PENALTY MODIFIERS
# ============================================

func get_seven_insurance_refund(total_wagered: int) -> int:
	# Insurance Policy: Get 50% back
	if has_powerup(PowerupType.INSURANCE_POLICY):
		return int(total_wagered * 0.5)
	return 0

func should_apply_seven_shield() -> bool:
	# Seven Shield: First 7 doesn't hurt
	if has_powerup(PowerupType.SEVEN_SHIELD) and not seven_shield_used:
		seven_shield_used = true
		return true
	return false

func get_seven_penalty_multiplier() -> float:
	# Risk Taker: Lose 1.5x instead of 1x
	if has_powerup(PowerupType.RISK_TAKER):
		return 1.5
	return 1.0

# ============================================
# LEVEL START BONUSES
# ============================================

func get_bonus_rolls() -> int:
	var bonus = 0
	if has_powerup(PowerupType.EXTRA_CHANCES):
		bonus += 3
	return bonus

func get_bonus_starting_points() -> int:
	var bonus = 0
	if has_powerup(PowerupType.DEEP_POCKETS):
		bonus += 500
	return bonus

# ============================================
# SPECIAL ABILITIES
# ============================================

func can_reroll() -> bool:
	return has_powerup(PowerupType.SECOND_CHANCE) and not reroll_used

func use_reroll() -> void:
	reroll_used = true
	print("[PowerupManager] Reroll used")

# ============================================
# WIN STREAK TRACKING
# ============================================

func on_win() -> int:
	# Track win streak for Hot Streak powerup
	if not has_powerup(PowerupType.HOT_STREAK):
		return 0
	
	win_streak += 1
	print("[PowerupManager] Win streak: ", win_streak)
	
	# Award bonus on 3 wins in a row
	if win_streak >= 3:
		win_streak = 0  # Reset
		print("[PowerupManager] Hot Streak bonus! +1000 points")
		return 1000
	
	return 0

func on_miss() -> void:
	# Reset streak on miss
	win_streak = 0

func on_seven() -> void:
	# Reset streak on 7
	win_streak = 0

# ============================================
# UTILITY FUNCTIONS
# ============================================

func get_active_powerup_names() -> Array:
	var names = []
	for type in active_powerups:
		names.append(POWERUP_DATA[type]["name"])
	return names

func get_powerup_count() -> int:
	return active_powerups.size()
