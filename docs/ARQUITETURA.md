# Arquitetura — Urban Riders

## Princípios
- **GDScript tipado**, scripts referenciados por `preload` (sem dependência do cache de `class_name`).
- **Lógica pura separada da cena**: `bike_physics.gd` e `stamina.gd` não dependem de nós e são testadas diretamente.
- **Sinais** para comunicação (`crashed`, `recovered`, `out_of_hearts`); o HUD apenas observa o ciclista.
- **Configuração em Resource** (`resources/bike_default.tres` → `bike_config.gd`): todos os parâmetros de gameplay.
- **Leveza** (Mac M4 / 16 GB): renderizador *Mobile*, Cel Shading com 3 faixas, sombras de 2 cascatas até 45 m,
  céu procedural barato, sem pós-processamento caro.

## Estrutura
```
project.godot
scenes/main.tscn                 cena raiz (monta tudo por código)
scripts/core/main.gd             ambiente, luz, montagem, reinício, métricas de FPS no console
scripts/core/input_setup.gd      mapa de teclas (setas + letras)
scripts/core/camera_rig.gd       câmera 3ª pessoa: SpringArm3D + Camera3D
scripts/core/toon_materials.gd   fábrica/cache de materiais toon + contorno
scripts/physics/bike_config.gd   parâmetros (Resource)
scripts/physics/bike_physics.gd  funções puras: aceleração, resistência, curva, aderência, inclinação
scripts/physics/stamina.gd       resistência física (energia)
scripts/player/bike_controller.gd CharacterBody3D: estados RIDING/CRASHED/OUT, quedas, recuperação
scripts/player/rider_visual.gd   modelo provisório + animação procedural (IK das pernas)
scripts/ui/hud.gd                HUD desenhado (retrato, corações, energia, velocidade, turbo)
scripts/world/test_track.gd      pista de testes procedural
shaders/toon.gdshader            Cel Shading
shaders/outline.gdshader         contorno de quadrinho (casca invertida)
shaders/red_sky.gdshader         céu vermelho tempestuoso
tests/run_tests.gd               testes de unidade e integração
```

## Física híbrida
- Velocidade escalar ao longo do eixo da bicicleta, projetada no plano do piso (rampas).
- Pedalar busca a **velocidade-alvo** (24 km/h; até 40 km/h com S, que sobe em ~4 s) com aceleração progressiva.
- Resistências: rolamento + ar (v²) + freio progressivo + componente da gravidade em rampas.
- Curva: esterço cinemático que diminui com a velocidade, limitado pelo **equilíbrio assistido** (0,75 g).
- **Aderência por piso** (asfalto 1,0; grama 0,6; molhado 0,45): se a curva pedida excede o limite, derrapa;
  derrapando por mais de 0,6 s → queda.
- Inclinação visual = atan(v·ω/g), limitada a 30°.
- Quedas: impacto frontal > 14 km/h, perda de controle ou aterrissagem forte. Recuperação em 2,5 s,
  com 1 s de imunidade. 3 quedas → perde a corrida.

## Energia
| Situação | Efeito |
|---|---|
| Parado | +9 %/s |
| Sem pedalar, rodando | +5 %/s |
| Pedalada normal | −1 %/s (leve: +1,5 %/s quando cansado) |
| Turbo (S) | até −9 %/s |
| ≤ 10 % | "Cansado": sem turbo até voltar a 30 % |
| < 40 % | velocidade máxima reduzida (até 70 %) |
