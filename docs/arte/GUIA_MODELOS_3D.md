# Guia de criação de arte — Urban Riders

## Fluxo
1. **ChatGPT** gera as imagens de referência (prompts em `docs/arte/prompts/`).
2. **Meshy** (meshy.ai) ou **Tripo** (tripo3d.ai) convertem imagem → modelo 3D.
3. **Rig/animação dos personagens:** auto-rig do próprio Meshy/Tripo, ou **Mixamo** (mixamo.com, gratuito).
4. Você me envia os arquivos (pasta `assets/models/` no repositório); eu integro, ajusto escala, shaders e animações.

## Formato que preciso
| Item | Formato | Detalhes |
|---|---|---|
| Personagens | **GLB** (glTF 2.0 binário) | Com textura embutida; **com esqueleto (rig)**. Se usar Mixamo: exporte **FBX** "with skin", ~**8–15 mil triângulos** |
| Animações (Mixamo) | **FBX** "without skin" | Opcional: *Bicycle/Biking*, *Falling*, *Standing up*, *Idle*. A pedalada eu também consigo fazer por código |
| Bicicleta BMX | **GLB** | Sem rig. ~5 mil triângulos. Rodas, guidão e pedivela idealmente como **peças separadas** (se o gerador não separar, eu separo/aproximo) |
| Objetos (casas, poste, carro…) | **GLB** | 500–5 mil triângulos (casas até 8 mil) |
| Texturas de piso | **PNG** 1024×1024 ou 2048×2048 | Sem emendas (tileable) |
| Retratos do HUD | **PNG** | Quadrado, ≥ 512×512 |

Configurações ao exportar no Meshy/Tripo: **GLB**, polígonos **"low/medium"** (não "high"), textura **1024 ou 2048**,
**sem PBR pesado** se houver opção (só cor base). Escala/orientação não importam — eu corrijo.

## Ordem de prioridade
1. **Andrew-Mike** (prompts 01–04) e **BMX** (17–20) → valida o fluxo inteiro.
2. Lucienne, Russ, Mint (05–16).
3. Objetos do cenário (21–33) e texturas (34–37).
4. Retratos do HUD (38–41).

## Dicas para o ChatGPT
- **Uma conversa nova por personagem.** Gere a vista **frontal** primeiro; repita até gostar.
  Depois, na **mesma conversa**, gere lateral, costas e 3/4 — assim o personagem fica consistente.
- Se uma vista sair diferente (roupa/cabelo mudou), responda: *"Corrija para ficar idêntico à imagem frontal: [o que mudou]."*
- Baixe as imagens no tamanho máximo.
- No Meshy/Tripo use o modo **multi-view** (frontal + lateral + costas). Se só aceitar uma, use a **frontal**.

## Licença e direitos
- Verifique se o seu plano no Meshy/Tripo permite **uso comercial** (planos gratuitos às vezes não permitem).
- Os prompts evitam marcas, logotipos e elementos de obras existentes (Hawkins, criaturas etc.).
