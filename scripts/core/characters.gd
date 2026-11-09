extends RefCounted
## Catálogo do elenco: aparência provisória (cores, cabelo, proporções) de cada ciclista.

const ANDREW := "andrew_mike"
const LUCIENNE := "lucienne"
const RUSS := "russ"
const MINT := "mint"
const RIVALS: Array[String] = [LUCIENNE, RUSS, MINT]


static func look(id: String) -> Dictionary:
	match id:
		LUCIENNE:
			return {
				"name": "Lucienne", "color": Color(0.45, 0.7, 1.0),
				"frame": Color(0.35, 0.6, 0.85), "jacket": Color(0.45, 0.6, 0.8), "stripe": null,
				"shirt": Color(0.92, 0.9, 0.85), "pants": Color(0.24, 0.34, 0.58), "shins": Color(0.24, 0.34, 0.58),
				"cuff": Color(0.32, 0.43, 0.66), "shoes": Color(0.95, 0.95, 0.93),
				"skin": Color(0.95, 0.76, 0.64), "hair": Color(0.4, 0.22, 0.1), "hair_style": "pigtails",
				"accent": Color(0.85, 0.1, 0.1), "backpack": false, "scale": 0.97,
			}
		RUSS:
			return {
				"name": "Russ", "color": Color(1.0, 0.5, 0.15),
				"frame": Color(0.2, 0.35, 0.15), "jacket": Color(0.33, 0.36, 0.2), "stripe": Color(0.9, 0.45, 0.1),
				"shirt": Color(0.08, 0.08, 0.08), "pants": Color(0.25, 0.25, 0.27), "shins": Color(0.25, 0.25, 0.27),
				"cuff": Color(0.25, 0.25, 0.27), "shoes": Color(0.2, 0.2, 0.2),
				"skin": Color(0.97, 0.8, 0.7), "hair": Color(0.85, 0.32, 0.08), "hair_style": "spiky",
				"accent": Color(0.08, 0.08, 0.08), "backpack": false, "scale": 1.03,
			}
		MINT:
			return {
				"name": "Mint", "color": Color(0.4, 0.95, 0.75),
				"frame": Color(0.45, 0.85, 0.7), "jacket": Color(0.5, 0.88, 0.72), "stripe": Color(0.95, 0.95, 0.95),
				"shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.12, 0.14, 0.3), "shins": Color(0.5, 0.5, 0.52),
				"cuff": Color(0.95, 0.95, 0.95), "shoes": Color(0.95, 0.95, 0.93),
				"skin": Color(0.36, 0.22, 0.14), "hair": Color(0.06, 0.05, 0.05), "hair_style": "puff",
				"accent": Color(0.45, 0.9, 0.7), "backpack": false, "scale": 0.9,
			}
		_:
			return {
				"name": "Andrew-Mike", "color": Color(1.0, 0.25, 0.2),
				"frame": Color(0.78, 0.07, 0.06), "jacket": Color(0.1, 0.12, 0.3), "stripe": Color(0.93, 0.92, 0.88),
				"shirt": Color(0.8, 0.12, 0.12), "pants": Color(0.24, 0.34, 0.58), "shins": Color(0.24, 0.34, 0.58),
				"cuff": Color(0.36, 0.47, 0.7), "shoes": Color(0.95, 0.95, 0.93),
				"skin": Color(0.9, 0.68, 0.52), "hair": Color(0.36, 0.2, 0.1), "hair_style": "wavy",
				"accent": Color(0.4, 0.24, 0.1), "backpack": true, "scale": 1.0,
			}
