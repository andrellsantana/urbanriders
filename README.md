# Urban Riders

Corrida 3D de bicicletas em **Red City** — Godot 4 + GDScript tipado, para macOS.

> **Estado atual:** **versão 1.0 (MVP)** — corrida completa contra Lucienne, Russ e Mint em Red City.
> Personagem e cenário são **geometria provisória** (visual definitivo fica para a versão 2).

![Corrida em Red City](docs/screenshots/corrida_rivais.png)

## Como jogar no Mac

1. Baixe a **Godot 4** (versão estável, edição padrão — *não* a .NET) em <https://godotengine.org/download/macos/>
   e arraste `Godot.app` para **Aplicativos**. Na primeira abertura: clique com o botão direito → **Abrir**.
2. Baixe o projeto:
   ```bash
   git clone -b claude/adoring-mccarthy-f6kfvr https://github.com/andrellsantana/urbanriders.git
   ```
   (Se já tiver a pasta: `git pull`.)
3. Na Godot: **Importar** → selecione `urbanriders/project.godot` → **Importar e Editar**.
   Se a Godot perguntar sobre converter/atualizar o projeto para a versão nova, aceite.
4. Pressione **Cmd + B** (ou clique no botão ▶ no canto superior direito) para jogar.
   *(No Mac, F5 só funciona como **fn + F5**.)*
5. Para a pista de testes da física: abra `scenes/test_track.tscn` e pressione **Cmd + R** (rodar cena atual).

## Gerar o aplicativo para Mac (versão 1.0)

O jogo vira um **Urban Riders.app** que abre com dois cliques, sem a Godot (Apple Silicon e Intel).

1. Abra o projeto na Godot.
2. Menu **Editor → Gerenciar Modelos de Exportação…** (*Manage Export Templates*) → **Baixar e Instalar**.
   (Só na primeira vez; são ~1 GB.)
3. Menu **Projeto → Exportar…** (*Project → Export*). O perfil **macOS** já está configurado.
4. Clique em **Exportar Projeto…**, desmarque **"Exportar com Depuração"** (*Export With Debug*),
   escolha onde salvar (ex.: Área de Trabalho) com o nome `Urban Riders.zip` e confirme.
5. Dê dois cliques no `.zip`: aparece o **Urban Riders.app**. Arraste-o para **Aplicativos** se quiser.
6. Na **primeira** abertura o macOS avisa que o desenvolvedor não é identificado:
   clique com o botão direito no app → **Abrir** → **Abrir**. (Ou: Ajustes do Sistema → Privacidade e Segurança → **Abrir Mesmo Assim**.)
   Nas próximas vezes, é só dar dois cliques.

> O app é assinado localmente ("ad-hoc"), sem conta paga de desenvolvedor Apple. Para distribuir a outras
> pessoas sem esse aviso, seria preciso assinatura e notarização da Apple (fora do escopo do MVP).

## Controles

| Tecla | Ação |
|---|---|
| **↑** ou **W** (segurar) | Pedalar (ritmo normal, ~24 km/h) |
| **S** (segurar) | Acelerar gradualmente até 40 km/h (gasta mais energia) |
| **↓** ou **Espaço** | Frear (progressivo) |
| **← →** ou **A D** | Curvas |
| **R** | Reiniciar |
| **Esc** | Pausa (Continuar, Reiniciar, Configurações, Sair) |

## Menus e configurações
- **Menu inicial:** Jogar, Configurações, Sair (setas + Enter ou mouse).
- **Configurações:** qualidade gráfica (Baixa/Média/Alta), sombras, tela cheia e volume — salvas no computador.
  Se o FPS cair, use **Baixa** ou desligue as sombras.

## Sons e efeitos
Todos os sons são **sintetizados pelo próprio jogo** (sem arquivos externos): pneus, corrente, catraca livre
ao soltar o pedal, freio, vento, quedas, encostões, poças, bipes da largada, checkpoints, fanfarra e trovões.
Efeitos: poeira nas quedas, respingos nas poças, folhas de outono caindo, tremor de câmera e linhas de velocidade no turbo.

## O que testar

**Na pista:**
- **Aceleradores** (setas amarelas no chão): impulso até 44 km/h sem gastar energia.
- **Rampas** de madeira: salto e impulso no pouso.
- **Obstáculos** (cavaletes de obra, cones, lixeira, caçamba) — sempre há passagem ao lado.
- **Carros** indo e vindo nas faixas externas; desviam dos estacionados (invadindo a sua faixa!) e buzinam.
- **Pedestres** nas faixas de pedestres — alguns distraídos atravessam com você chegando. Esbarrar derruba.
- **O cão** (a ¾ da corrida): late para quem passa, atravessa na frente dos 3 primeiros (quem encosta perde o embalo)
  e corre atrás do último colocado — o susto faz pedalar mais forte por 10 s sem gastar energia.
- **Relâmpagos e trovões** de vez em quando.

**Rivais (IA)** — chances iguais, habilidades diferentes; cada corrida favorece um de forma diferente:
- **Mint** (verde-menta): a melhor nas curvas, nunca perde um acelerador, joga limpo.
- **Lucienne** (azul): cautelosa nas curvas, mas a **mais rápida nas retas** (turbo até 42 km/h e mais econômico); imprevisível.
- **Russ** (laranja): o rei das rampas (pouso com impulso maior); trapaceiro — **persegue você**: segura o ritmo para te esperar, fecha a sua frente
  ("Sai da frente!"), joga a bicicleta em cima ("Abre!"), devolve ultrapassagens ("Volta aqui!") e corta esquinas pela calçada.
  Encostões **empurram**; trombada forte **derruba**.
- Todos variam de corrida para corrida ("dia bom ou ruim") e arriscam mais no turbo quando ficam para trás.
- Posição ao vivo à esquerda; rivais aparecem como pontos coloridos no minimapa; quadro final com tempos.

**Corrida no bairro (cena principal):**
- Contagem 3-2-1-JÁ!, depois siga a **seta amarela** no topo e o **minimapa** (canto superior direito).
- Passe pelos **12 checkpoints em ordem** (portal com cortina amarela) e cruze a **LARGADA/CHEGADA**.
- Ruas fora da rota estão fechadas por **barreiras laranja e brancas**.
- **Poças** (manchas vermelhas) perto de duas esquinas e numa reta: curva rápida nelas derruba.
- Andar na contramão mostra **SENTIDO ERRADO!**. Três quedas = corrida perdida.
- Ao chegar: classificação final, tempo e **recorde** (salvo no computador).
- **Energia:** pedalando normal ela gasta muito pouco (~7% por minuto) e **não** recupera;
  só recupera com o **pedal solto**, freando ou parado (seta verde "recuperando" ao lado da barra).
  O turbo (S) é o que esgota. Abaixo de 25% a velocidade máxima cai.
- Os rivais seguem a mesma regra: você os verá **soltar o pedal** para recuperar ("recuperando" sobre o nome)
  e ficar "cansado/cansada" quando exageram.

**Pista de testes** (`scenes/test_track.tscn`): slalom de cones, rampa, piso molhado, grama e muros.

## Testes automatizados

```bash
./tests/run_tests.sh
```
(ou `GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./tests/run_tests.sh`)

## Documentação

- [Arquitetura](docs/ARQUITETURA.md)
- [Plano de fases](docs/PLANO.md)
- [Personagens e direção de arte](docs/PERSONAGENS.md)
- [Registro de alterações](docs/CHANGELOG.md)
