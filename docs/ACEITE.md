# Critérios de aceite do MVP — versão 1.0

| Critério (especificação, seção 8) | Situação | Como foi verificado |
|---|---|---|
| O jogo inicia e executa no macOS | ✅ | Testado pelo usuário no Mac (M4) a cada fase |
| O garoto consegue completar o circuito pedalando | ✅ | Testes automáticos (volta completa) + corridas do usuário |
| A câmera acompanha o ciclista sem atravessar paredes | ✅ | Testes automáticos (braço de mola encurta com parede atrás) |
| A bicicleta acelera, freia e inclina de maneira convincente | ✅ | Avaliação do usuário ("muito boa") + testes de física |
| A resistência física afeta o desempenho | ✅ | Testes (cansaço reduz velocidade; turbo bloqueado) |
| Colisões fortes e curvas críticas provocam quedas | ✅ | Testes (parede, ciclista, piso molhado, aterrissagem) |
| Os três adversários completam a corrida sem bloqueios permanentes | ✅ | Testes (corrida completa; reposicionamento automático) |
| Os checkpoints impedem atalhos ilegais | ✅ | Testes (pular checkpoint não conta; chegada só após todos) |
| A classificação final está correta | ✅ | Testes (ordem por tempo de chegada) |
| O jogo alcança a meta de desempenho no equipamento de referência | ⚠️ parcial | 60 FPS em 1080p/1600×900 no M4; ~50 FPS a 5100×1943 (resolução nativa ultrawide) |
| O build funciona independentemente do editor Godot | ⏳ | Perfil de exportação macOS pronto; gerar o app no Mac (README) e confirmar |

## Requisitos funcionais
| ID | Requisito | Situação |
|---|---|---|
| RF01 | Controlar o garoto e a bicicleta | ✅ |
| RF02 | Pedalar, frear e fazer curvas | ✅ |
| RF03 | Câmera próxima com acompanhamento suave | ✅ |
| RF04 | Aceleração, inércia e aderência | ✅ |
| RF05 | Resistência física e recuperação | ✅ |
| RF06 | Quedas em colisões e manobras críticas | ✅ |
| RF07 | Três adversários com IA | ✅ |
| RF08 | Circuito urbano com checkpoints | ✅ |
| RF09 | Cronômetro, posição e classificação | ✅ |
| RF10 | Reinício e conclusão de corrida | ✅ |
| RF11 | HUD com velocidade e energia | ✅ |
| RF12 | Sons e animações de pedalada | ✅ (sons sintetizados; animação procedural) |
| RF13 | Dois atalhos opcionais | ➖ substituído por aceleradores e rampas (decisão do usuário) |
| RF14 | Menu de configurações gráficas | ✅ |

## Pendências conhecidas (versão 2)
- Visual definitivo: modelos 3D dos personagens, bicicletas e cenário (prompts em `docs/arte/`).
- Assinatura e notarização Apple para distribuir sem aviso de segurança.
- Opcional: modo de dificuldade e mais circuitos.
