import os
import shutil
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def mariadb_program(name):
    folder = os.environ.get("HOA_MARIADB") or os.path.join(ROOT, "server", "mariadb")
    program = os.path.join(folder, "bin", name + (".exe" if os.name == "nt" else ""))
    if os.name == "nt" or os.path.exists(program):
        return program
    for prefix in (os.environ.get("HOMEBREW_PREFIX"), "/opt/homebrew", "/usr/local"):
        if prefix and os.path.exists(os.path.join(prefix, "opt", "mariadb@11.4", "bin", name)):
            return os.path.join(prefix, "opt", "mariadb@11.4", "bin", name)
    return shutil.which(name) or program


MARIADB = mariadb_program("mariadb")
OUT = os.path.join(ROOT, "Interface", "GlueXML", "BonkClassInfo.lua")
STARTER_LINE_MAX = 31

CLASSES = [
    ("WARRIOR", 1, "Fights in the thick of the horde. Every swing hits all around you, and there is no Rage to manage."),
    ("PALADIN", 2, "Seals change every strike and Judgement releases them. Holy light burns all around you, and hammers finish the wounded."),
    ("HUNTER", 4, "Shoots from range while pets fight at your side. Marks, stings and traps set up the kill."),
    ("ROGUE", 8, "The fastest single-target attacks in the game. Every stab carries a poison or an opener."),
    ("PRIEST", 16, "Healing that overflows into damage, a ring of light that hits far, and Decay that spreads from mind to mind."),
    ("SHAMAN", 64, "Lightning that builds Static, Windfury bursts in melee, and totems that hold the ground."),
    ("MAGE", 128, "Frost controls and shatters, Fire burns and nukes, and Arcane blinks through the horde."),
    ("WARLOCK", 256, "A crew of demons at your side, afflictions that grow with time, and fel fire that rains on the pack."),
    ("DRUID", 1024, "A shapeshifter that changes between Moonkin, Cat, Bear and Tree of Life. Every spell works in every form, and the right form makes it 30% stronger."),
]

SPECS = {
    101: ("Ability_Warrior_SavageBlow", "Stack Bleed on the pack, then cash it in with Mortal Strike."),
    102: ("Ability_Warrior_InnerRage", "Critical strikes and kills Enrage you, and Enrage makes you strike faster."),
    103: ("INV_Shield_06", "Get hit, absorb it with your Shield, and punish it."),
    201: ("Spell_Holy_HolyBolt", "Holy strikes from afar: Exorcism, falling hammers and light that heals with every strike."),
    202: ("Spell_Holy_DevotionAura", "Holy ground and auras burn whoever comes close, while Divine Shield blocks the big hits."),
    203: ("Spell_Holy_AuraOfLight", "Crusader Strike and Seals on every swing, released by Judgement, with hammers for the wounded."),
    301: ("Ability_Hunter_BeastTaming", "Pets do the fighting: your cat bleeds the pack and the spirit wolf leads it."),
    302: ("Ability_Marksmanship", "Shots, volleys and piercing arrows, with Hunter's Mark on the biggest group."),
    303: ("Ability_Hunter_SwiftStrike", "Poison stings, and traps that burn or slow whatever walks in."),
    401: ("Ability_Rogue_Eviscerate", "Poison on every hit, then Envenom the most poisoned enemy."),
    402: ("Ability_BackStab", "Fast blades: Blade Flurry, Eviscerate and Killing Spree through the pack."),
    403: ("Ability_Stealth", "Ambush every new enemy you hit, and Shadow Dance to do it again."),
    501: ("Spell_Holy_WordFortitude", "Shields, fear and binding, while Penance punishes whoever strikes you."),
    502: ("Spell_Holy_PrayerOfHealing02", "Heals that overflow into damage, and Holy Word strikes the strongest enemy."),
    503: ("Spell_Shadow_ShadowWordPain", "Plant Decay on the far edge of the horde and spread it from mind to mind."),
    701: ("Spell_Nature_Lightning", "Lightning builds Static on the pack, and shocks cash it in."),
    702: ("Spell_Nature_LightningShield", "Windfury swings in melee, and every 5th hit hurls free lightning."),
    703: ("Spell_Nature_MagicImmunity", "Totems at your feet burn the pack and heal you while you hold the ground."),
    801: ("Spell_Holy_MagicalSentry", "Blink through the horde. Every Blink sets off Arcane Explosion and Missiles."),
    802: ("Spell_Fire_FireBolt02", "Burn everything, then nuke the most burning enemies."),
    803: ("Spell_Frost_FrostBolt02", "Chill and freeze the pack, then shatter frozen enemies with Frostbolt."),
    901: ("Spell_Shadow_DeathCoil", "Corruption and Curse of Agony grow with time while Drain Life keeps you alive."),
    902: ("Spell_Shadow_Metamorphosis", "A crew of demons out at once: Imp, Voidwalker, Succubus and Felhunter."),
    903: ("Spell_Shadow_RainOfFire", "Fel fire: Shadow Bolt, Immolate, Hellfire and Rain of Fire on the pack."),
    1101: ("Spell_Nature_StarFall", "Moonkin form. Starlight on the strongest enemy, Moonfire on the pack and storms on the crowd."),
    1102: ("Ability_Racial_BearForm", "Cat and Bear form. Bleed the pack, Shred the deepest bleeder, and shift to Bear when you are hurt."),
    1103: ("Spell_Nature_HealingTouch", "Tree of Life. Heals that hurt, while Treants and roots hold the crowd."),
}

SPEC_NAMES = {1101: "Balance", 1102: "Feral", 1103: "Restoration"}

LINES = {
    300: "Strikes every enemy within 8 yards",
    301: "Makes the 3 nearest enemies Bleed",
    302: "Your critical strikes make enemies Bleed",
    303: "Hits harder for each stack of Bleed",
    304: "Strikes 3 enemies and heals you",
    305: "Slays normal enemies below 20% health",
    306: "Spins through the pack, twice when Enraged",
    307: "A Shield that soaks damage, stacking up",
    308: "Blasts nearby enemies and slows their attacks",
    309: "Strikes back when you are hit",
    310: "Hits harder the bigger your Shield",
    805: "Heavy Holy strike on the strongest enemy",
    807: "Your strikes heal you",
    812: "Hammers of light fall on the pack",
    804: "Holy ground that burns enemies on it",
    809: "A bubble that blocks the next big hit",
    810: "Burns every enemy close to you",
    811: "Stuns the strongest enemy",
    800: "Heavy strike with splash damage",
    801: "Hammers 3 enemies and releases your Seals",
    802: "Every 3rd strike bursts with light",
    803: "Your hits deal extra Holy damage",
    806: "Holy burst around you that heals",
    813: "Slays wounded enemies",
    201: "Your cat fights for you",
    211: "A spirit wolf that empowers your pets",
    7: "Shoots the nearest enemy",
    37: "6 arrows in a cone",
    137: "Rains arrows on the largest group",
    203: "A shot that pierces a whole line",
    205: "Marked enemies take more damage",
    38: "Poisons the nearest enemies",
    202: "A trap that explodes and burns the ground",
    204: "A trap that slows the pack",
    604: "Two poisoned stabs on the nearest enemy",
    605: "Your hits apply Poison",
    606: "Knives in every direction",
    607: "Strikes the most poisoned enemy",
    600: "Fast stabs on the nearest enemy",
    601: "Your hits strike 4 more enemies",
    602: "Heavy strike with double crit chance",
    603: "8 strikes on random enemies",
    608: "Shurikens at fresh enemies",
    609: "Your first hit on each enemy ambushes it",
    610: "More damage, and Ambush again",
    611: "Dodge far more attacks for a while",
    504: "A shield that makes you faster",
    505: "Holy bolts at whoever struck you",
    506: "Nearby enemies flee in fear",
    507: "Binds the strongest enemy",
    500: "Smites the 2 nearest enemies",
    501: "Heals you, then smites at full health",
    502: "A ring of light that heals you",
    503: "Heavy Holy strike on the strongest enemy",
    508: "Plants Decay on far enemies",
    509: "Flays the nearest enemy until it dies",
    510: "Spreads Decay from the most decayed enemy",
    511: "A Shadowfiend that heals you",
    711: "Zaps enemies that strike you",
    700: "Lightning that bounces once",
    701: "Lightning that jumps to 4 more",
    702: "Burns the strongest enemy",
    703: "Discharges Static on the pack",
    704: "Swings with Windfury bursts",
    705: "Two strikes that build Static",
    706: "Every 5th hit hurls free lightning",
    707: "2 spirit wolves fight for you",
    708: "A totem that hurls fire",
    709: "A totem that pulses fire around you",
    710: "A totem that heals you",
    410: "An elemental fights for you",
    407: "Your dash teleports and explodes",
    408: "Arcane blast around you",
    409: "5 missiles at the nearest enemy",
    403: "Fire bolt that leaves enemies Burning",
    404: "A pillar of fire on the largest group",
    405: "Huge fireball on elites and bosses",
    406: "Blasts the most burning enemies",
    400: "Shatters frozen enemies",
    401: "Ice shards on the largest group",
    402: "Frost blast around you",
    904: "Decay that grows on the nearest enemies",
    905: "Agony on the healthiest enemies",
    906: "Drains life while you move",
    900: "An Imp that hurls fire",
    901: "A Voidwalker that bursts in a void nova",
    902: "A Succubus that lashes a wide arc",
    903: "A Felhunter that bites afflicted enemies",
    907: "Kills fire more Shadow Bolts",
    908: "Fire that leaves enemies Burning",
    909: "Fire burns everything around you",
    910: "Fire rains on the largest group",
    1013: "Press 'R' to change form",
    1001: "Starlight on the strongest enemy",
    1002: "Moonfire on the nearest enemies",
    1003: "A storm on the largest group",
    1004: "Makes the 3 nearest enemies Bleed",
    1005: "Strikes the enemy with the most Bleed stacks",
    1006: "Hits every enemy within 10 yards",
    1007: "Heals you for each enemy close by",
    1008: "Heals you and lashes nearby enemies",
    1009: "2 Treants fight at your side",
    1010: "Roots the 3 nearest enemies",
    1011: "Pulses that hurt enemies and heal you",
    1012: "Enemies that strike you take damage",
}


def query(sql):
    result = subprocess.run([MARIADB, "-h", "127.0.0.1", "-P", "3306", "-uroot", "-proot", "-N", "-B", "-r", "mangos", "-e", sql], capture_output=True, text=True, encoding="utf-8", check=True)
    return [line.split("\t") for line in result.stdout.splitlines() if line]


def lua(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "|n") + '"'


def spell_entry(row):
    spell_id, name, icon, description = int(row[0]), row[1], row[2], row[3]
    if spell_id not in LINES:
        raise SystemExit(f"No short line for spell {spell_id} {name}")
    return "{ name = %s, icon = %s, line = %s, tip = %s }" % (lua(name), lua("Interface\\Icons\\" + icon), lua(LINES[spell_id]), lua(description))


def main():
    trees = {int(r[0]): r[1] for r in query("SELECT id, name FROM bonk_mastery_tree")}
    order = {int(r[0]): int(r[1]) for r in query("SELECT id, `order` FROM bonk_mastery_tree")}
    out = ["BONK_CLASS_INFO = {"]
    for token, mask, blurb in CLASSES:
        rows = query(f"SELECT id, name, icon, description, spec, starter_class_mask FROM bonk_weapon WHERE evolves_from = 0 AND class_mask = {mask} ORDER BY id")
        starter = next((r for r in rows if int(r[5]) & mask), None)
        specs = sorted({int(r[4]) for r in rows if int(r[4])}, key=lambda s: (order.get(s, s), s))
        shared = [r for r in rows if int(r[4]) == 0 and r is not starter]
        out.append(f"\t{token} = {{")
        out.append(f"\t\tblurb = {lua(blurb)},")
        if starter and len(LINES[int(starter[0])]) > STARTER_LINE_MAX:
            raise SystemExit(f"Starter line for {starter[1]} is longer than {STARTER_LINE_MAX} characters and would run past the panel")
        if starter:
            out.append(f"\t\tstarter = {spell_entry(starter)},")
        out.append("\t\tshared = {")
        for r in shared:
            out.append(f"\t\t\t{spell_entry(r)},")
        out.append("\t\t},")
        out.append("\t\tspecs = {")
        for spec in specs:
            icon, text = SPECS[spec]
            name = trees.get(spec) or SPEC_NAMES[spec]
            spec_icon = lua("Interface\\Icons\\" + icon)
            out.append(f"\t\t\t{{ name = {lua(name)}, icon = {spec_icon}, text = {lua(text)}, spells = {{")
            for r in rows:
                if int(r[4]) == spec:
                    out.append(f"\t\t\t\t{spell_entry(r)},")
            out.append("\t\t\t} },")
        out.append("\t\t},")
        out.append("\t},")
    out.append("};")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print(OUT)


main()
