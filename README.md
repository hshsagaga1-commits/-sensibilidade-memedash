
## Macro circular de emote V2 - iniciar / cancelar com o mesmo botao

Com base no relatorio do X12, os botoes visiveis estao em `PlayerGui/Mobile/Emote` e `PlayerGui/EmotesGui/MainGui/Sector6/ViewportFrame/button`. Esse macro circular guarda esses caminhos e busca as instancias atuais, sem depender das coordenadas especificas da gravacao.

**Comportamento solicitado:** toque 1 no circulo verde `🎭` abre o menu original (se ainda estiver fechado) e tenta clicar no emote do Setor 6; toque 2 no circulo vermelho `■` **apenas** tenta clicar em `Mobile/Emote` de novo, para cancelar o emote, sem tentar selecionar o setor. Depois volta a verde e repete. O estado alterna somente quando o acionamento retorna sem erro; isso nao comprova que a animacao foi realmente executada ou cancelada.

**Posicionamento:** o pequeno cadeado `🔓` deixa o circulo arrastavel. `🔒` trava a posicao (toques continuam funcionando). Arrastar mais de 9 pixels nao executa o macro; um toque curto executa. A engrenagem `⚙` abre ajustes de setor 1-8 e o botao `COPIAR LOG`. O arquivo do macro anterior `MemeDashEmoteMacroOneTap.lua` permanece intacto.

**Compatibilidade:** ainda NAO testado no Delta/iPhone. Os botoes do jogo podem exigir callbacks que nao sejam acionaveis por script. O macro tenta `firesignal` e, em caso de bloqueio, clique virtual por APIs que podem nao estar disponiveis no executor. Enviar `COPIAR LOG` em caso de problema. Nao altera camera, personagem, controles, servidores ou remotes. Sem garantia de banimento ou compatibilidade.

**Loader V2 sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/MemeDashEmoteMacroCircularV2.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

## X12: identificar botoes de emote para futuro macro (read-only)

O usuario quer um **unico botao** para abrir o menu de emotes mobile e selecionar um emote. Para evitar inventar caminhos de GUI, o X12 observa dois toques reais feitos pelo usuario usando a API oficial `PlayerGui:GetGuiObjectsAtPosition` (sem simular cliques nem alterar a UI nativa).

**Uso:** execute somente o diagnostico X12, toque INICIAR, toque o botao ORIGINAL do menu de emotes do MemeDash, toque um emote da lista, e depois COPIAR. Envie o relatorio completo. Se a janela cobrir os botoes, pode arrasta-la pelo titulo. REFAZER recomeca a captura.

O relatorio salva no momento do toque: hierarquia de GuiObject, possivel GuiButton pai, tipo, nome, texto, imagem Roblox asset, AbsolutePosition/Size e ScreenGui. Isso identifica candidatos, **nao revela a callback interna do botao nem garante que clicks possam ser simulados publicamente**. Botoes em CoreGui, UI 3D ou protecoes do jogo podem impedir a descoberta/automacao; nao prometer macro antes de analisar o resultado.

**Loader X12 sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/MemeDashX12EmoteButtonInspector.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

Nenhum X9/X10/X11 ou script de sensibilidade foi alterado ou apagado.
## V8.3: correcao da CAMERA invertida nos dois eixos

O usuario esclareceu que a CAMERA (nao o corpo) estava invertida: dedo para a esquerda virava a camera a direita, dedo para cima virava a camera para baixo, e vice-versa. A V8.2 havia tentado corrigir erroneamente a orientacao do corpo com +180 graus.

A V8.3 corrige isso **na entrada de toque**, com `invertX=true` e `invertY=true` por padrao. A UI mostra `X normal` e `Y normal` para essas configuracoes, por refletirem a experiencia do jogador. Preserva o multiplicador de sensibilidade de 0.1x a 2.0x e o controle horizontal CORPO ON, mantendo `reverseBodyTurn=false`. A opcao de giro do corpo em 180 graus continua disponivel, mas agora com `flipBodyFacing=false` por padrao (`FRENTE 0`).

Se o sentido ficar errado, os botoes X/Y continuam permitindo alternar cada eixo independentemente. O codigo substitui temporariamente o controlador de camera original apenas quando ON e sensibilidade diferente de 1.0x, e tenta restaura-lo no OFF, 1.0x ou X. **Ainda nao foi testado dentro do jogo:** confirme se a camera segue o dedo e o corpo acompanha sem problemas de movimento. Se falhar, use OFF e reentre no jogo.

**Loader V8.3 sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/memedash_sensibilidade_v8_3_camera_natural.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

V8, V8.1 e V8.2 preservadas, sem alteracoes.

---
## Conclusao dos diagnosticos X9 v2 e X10 V3

O X9 v2 verificou que camera e corpo NEM SEMPRE acompanham a mesma rotacao: diferenca de ate 104,686 graus em uma sessao de 12 segundos (616/722 frames >5 graus), enquanto a camera foi Scriptable. Assim, nunca se deve presumir alinhamento 1:1 nem escrever em HumanoidRootPart.CFrame para ajustar a sensibilidade.

O X10 V3 confirmou: `Workspace.<LocalPlayer>.camera` existe como LocalScript, porem `camera Disabled=true` no momento observado. `Workspace.<LocalPlayer>.bodyrotation` tambem existe. O inspetor nao encontrou ValueBase ou atributos publicos pertinentes a sensibilidade em seu escopo de busca. Uma parte de PlayerGui foi limitada por seguranca de desempenho (budget 4500), portanto esse resultado NAO prova inexistencia universal de uma configuracao.

`UserInputService.MouseDeltaSensitivity`, `UserGameSettings.MouseSensitivity` e `UserGameSettings.GamepadCameraSensitivity` mostraram 1. Nada comprova que o controlador Scriptable de toque usa esses valores. O ajuste real teria que ocorrer na fonte ativa de transformacao de eventos touch em rotacao. Os hooks observacionais dos X9/X10 nao conseguem editar a entrada do controlador.

V5.2, V6 e V7 sao experimentais e apresentaram falhas. Nao considerar uma nova versao funcional enquanto nao houver uma estrategia verificavel sem conflito com a camera nativa. Todos os scripts anteriores permanecem preservados.

---
## RESULTADO DO TESTE V7 (30/10/2026): AINDA INSTAVEL

Video de 15,4 s analisado. A interface mostrou 0.1x com OFF, depois 0.1x com ON, e finalmente 2.0x com ON. Com modificacoes ativadas, a camera ficou desalinhada com o personagem; por volta de 12,7 segundos, passou a apontar quase verticalmente para baixo. Nao foi comprovada sensibilidade proporcional. **Nao usar V7 como solucao funcional**.

Motivo tecnico provavel: V7 acumula offsets visuais em Camera.CFrame com limites de yaw +/-65 graus e pitch +/-32 graus. Ao atingir esses limites, o movimento original da camera continua; o multiplicador deixa de representar a sensibilidade pretendida. Este mecanismo nao altera o processamento original de TouchMoved no controlador Scriptable do jogo.

Nenhum arquivo de V5.2, V6, V7 ou X9 foi alterado ou removido. Proxima investigacao: verificar se o LocalScript `Workspace.<jogador>.camera` ou algum objeto associado expoe NumberValue/atributo de sensibilidade, usando apenas APIs publicas de leitura. Sem essa informacao, outra versao de multiplicacao visual arriscaria repetir o defeito.

---
## AVISO: V6 com falhas no teste em video

A V6 de sensibilidade apresentou rotacoes instaveis em 2.0x e 0.5x. Nao e uma versao validada. Para comparar o movimento original, execute somente os diagnosticos, sem V5.2/V6. Desligar uma versao experimental pode exigir reentrar no jogo para restabelecer o estado original.

# MemeDash Sensibilidade / Diagnóstico

Scripts separados para testar a câmera no MemeDash.

## Diagnóstico (somente leitura)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/diagnostico.lua?nocache=" .. tostring(os.clock()), true))()
```

## Sensibilidade experimental para câmera Scriptable

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/memedash_sensibilidade.lua?nocache=" .. tostring(os.clock()), true))()
```

A sensibilidade usa um multiplicador entre 0.1x e 2.0x e tenta escalar as mudanças de rotação da câmera depois que o jogo atualiza `Workspace.CurrentCamera.CFrame`. Não altera WalkSpeed, salto ou joystick.

**Importante:** esta versão é experimental. Câmeras `Scriptable` são controladas pelo próprio jogo, e a compatibilidade depende de como o MemeDash calcula a câmera a cada frame. Comece em 1.0x; se a câmera tremer, ficar presa ou se comportar de forma estranha, aperte X para encerrar e voltar ao controle normal. O diagnóstico não é substituído nem alterado.

## MemeDash X9 - novo diagnostico de sensibilidade

Execute este diagnostico ANTES de tentar outra versao de sensibilidade. Ele so observa toques, camera e corpo durante 12 segundos; nao escreve em CFrame nem muda controles.

**Loader sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/MemeDashX9Diagnostic.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000, 999999)), true))()
```

Como usar: abra o MemeDash, execute, toque INICIAR, arraste a camera de um lado a outro e solte o dedo algumas vezes durante 12 segundos. Toque COPIAR e envie o relatorio. Se o executor nao tiver funcao de copiar, selecione o texto na caixa alternativa.

Os arquivos antigos `diagnostico.lua` e `memedash_sensibilidade.lua` continuam preservados. **Nao execute a sensibilidade v5.2 junto com o X9**: ela altera o CFrame da camera e do personagem e atrapalha o diagnostico da camera original.

## Sensibilidade MemeDash V6 (experimental, apos X9)

Arquivo: `memedash_sensibilidade_v6.lua`. Nao substitui V5.2 ou X9.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/memedash_sensibilidade_v6.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000, 999999)), true))()
```

IMPORTANTE: default 1.0x (sem modificacoes); 0.1x a 2.0x sao experimentais. V6 tenta corrigir a rotacao horizontal relativamente ao ultimo frame ajustado (evitando a realimentacao da V5.2) e a rotacao vertical de modo separado. **A V6 ajusta somente a rotacao Y da parte central do personagem, quando a camera e o corpo estao sincronizados; nao altera velocidade, joystick, salto nem posicao.** Aperte OFF ou X para parar imediatamente. Uso em jogo de terceiros pode ser incompatível ou infringir regras do jogo.

O relatorio do X9 apontou yaw total da camera=1193.586 graus; root=1193.594 graus, 538 eventos TouchMoved e camera Scriptable com FOV 100. A camera era atualizada em sincronizacao com o corpo; isto informa a V6, mas nao prova que ela funcionara em tempo real. Se girar ao contrario, inclinar, travar ou ficar instavel, toque OFF/X e encerre.

## X9 v2 - diagnostico atualizado

`MemeDashX9Diagnostic.lua` agora e o X9 v2: coleta 12 segundos, registra variacoes de pitch/yaw/roll da camera e yaw do corpo, compara o desvio entre ambos, identifica movimentos bruscos e movimentos apos soltar o dedo. O relatorio separa aproximadamente os toques da regiao direita da tela (provavel camera) daqueles da regiao esquerda (provavel joystick), mostrando as amostras ao longo do tempo. O script so observa: nao altera CFrame, FOV, controles nem sensibilidade.

A versao anterior continua preservada em `MemeDashX9Diagnostic_v1.lua`.

**Loader sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/MemeDashX9Diagnostic.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

**Teste:** abra o MemeDash, execute, aperte INICIAR, mova a camera durante 12 segundos e use COPIAR para mandar o relatorio. Se tiver que diagnosticar a V6 em particular, tome cuidado porque a V6 esta instavel; prefira o controle original primeiro. As regioes de toque sao aproximacoes e o X9 nao le o codigo-fonte privado do jogo.

## MemeDash V7: prototipo experimental camera-only (depois do X9 v2)

O X9 v2 mostrou grandes divergencias entre a orientacao horizontal da camera e do corpo durante movimentacao, entao a V7 nao altera HumanoidRootPart nem movimentos. Ela tenta restaurar o CFrame nativo no inicio do quadro, deixar o controlador do jogo calcular sua propria camera e aplicar um ajuste visual limitado no fim. Esta tecnica ainda depende da ordem de atualizacao do controlador Scriptable e NAO foi validada em jogo.

**Use somente depois de reentrar no MemeDash se testou a V6 instavel. Nao execute V5.2, V6 e V7 simultaneamente.** Comeca em 1.0x sem modificacoes; 0.5x e 2.0x sao experimentais. OFF/X tenta restaurar a camera original. Limites de ajuste: yaw 65 graus; pitch 32 graus. Nao substitui scripts anteriores.

### Loader V7 sem cache

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/memedash_sensibilidade_v7.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

**Limites conhecidos:** a variacao de sensibilidade pode deixar de ser proporcional quando bate no limite angular; controles do proprio jogo podem sobrescrever CFrame ou ignorar a ordem de prioridades; desativar pode nao restaurar estados internos. Se o angulo falhar, OFF, X e reentre. Envie o resultado para corrigirmos com base em evidencias.

## X10 - procura segura de configuracoes nativas da camera

Novo diagnostico `MemeDashX10SettingsInspector.lua`: identifica o controlador visivel do MemeDash (`Workspace.<jogador>.camera`) e inspeciona somente nomes de scripts, atributos publicos e ValueBase expostos relacionados a Camera/Touch/Sensitivity. NAO decompila scripts, nao modifica valores, nao escreve em CFrame, corpo ou botoes.

Esta investigacao veio depois do video de 15,4s que mostrou a V7 ainda instavel em 0.1x e 2.0x.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/MemeDashX10SettingsInspector.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

Uso: reentre no MemeDash sem V5/V6/V7 ativas, rode o loader acima, toque INSPECIONAR, depois COPIAR e envie o texto. A presenca de uma configuracao nao prova que o jogo a utiliza; em caso de nenhuma opcao exposta, sera preciso outra abordagem.

## X10 v2: busca focada (depois do primeiro relatorio)

X10 v1 mostrou scripts customizados `Workspace.<LocalPlayer>.camera` e `Workspace.<LocalPlayer>.bodyrotation`, mas o relatorio foi poluido por dezenas de `WalkSpeed` de emotes e a busca original atingiu o limite de 18.001 objetos.

X10 v2 mantem a interface e o botao COPIAR, mas concentra a inspecao nos scripts locais, suas configuracoes/filhos publicos, PlayerScripts e diretorios de configuracao visiveis. Ignora as arvores de assets de emotes; avisa se uma busca for interrompida por limite. Tudo somente leitura e sem decompilacao. A antiga foi preservada em `MemeDashX10SettingsInspector_v1.lua`.

**Loader X10 v2 sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/MemeDashX10SettingsInspector.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

## X10 V3: arquivo novo contra versao antiga em cache

Se o relatorio ainda mostrar `Instances scanned=18001` e dezenas de `ReplicatedStorage.Items.Emotes.*.WalkSpeed`, voce executou o X10 antigo, nao o focado. Use **MemeDashX10FocusedV3.lua**; o relatorio correto comeca com `===== MEMEDASH X10 V3 / FOCUSED CAMERA CONFIG =====` e inclui `Build=X10-V3-FOCUSED-20261030`. Essa versao ignora as arvores de emotes e registra limites de varredura.

**Loader X10 V3 sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/MemeDashX10FocusedV3.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

Arquivos X10 anteriores preservados (X10 original em `MemeDashX10SettingsInspector_v1.lua` e X10 focado v2 em `MemeDashX10SettingsInspector.lua`). Leia apenas os valores/atributos acessiveis da camera original; nenhum script e descompilado nem modificado.

## X11: linha do tempo da camera (somente leitura)

Depois do X10 V3, ficou claro que o script `Workspace.<LocalPlayer>.camera` estava `Enabled=false` e nao havia configuracao publica de sensibilidade exposta nos diretorios verificados. O X11 nao muda a camera nem o personagem. Ele registra em 10 pontos de cada frame quando o `Camera.CFrame` e o yaw do HumanoidRootPart mudam, e conta eventos de alteracao do CFrame. Isso pode indicar a janela de atualizacao, mas **nao prova qual script realizou a alteracao**.

Use em sessao limpa, sem V5/V6/V7. Toque INICIAR, movimente a camera e o personagem por 10 segundos, toque COPIAR e envie o relatorio. Nao ha nenhuma versao de sensibilidade validada ate o momento.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/MemeDashX11RenderTimeline.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

Arquivo original X10 e demais scripts mantidos sem alteracoes.

## V8 CONTROLADOR PROPRIO - PROTOTIPO EXPERIMENTAL (X11)

**ATENCAO:** V8 ainda NAO testada em MemeDash e NAO esta comprovada funcional. Use apenas se aceitar o risco de camera se comportar diferente; em caso de erro use OFF/X e, se necessario, reentre no jogo. Evite usar com outras versoes de sensibilidade ativadas.

O X11 (10 segundos, ~600 frames) mostrou alteracoes da camera E do corpo exclusivamente entre `PreCamera(199)` e `PostCamera(201)` em centenas de quadros. O script `Workspace.<jogador>.camera` estava `Enabled=true` nesse teste, diferentemente do X10 anterior, que encontrou `Disabled=true`. Portanto, a camera parece mudar de estado no decorrer do jogo. O timing nao prova qual script escreve Camera.CFrame.

**Mudanca de estrategia:** em vez de corrigir `CFrame` a posteriori ou escrever no `HumanoidRootPart`, a V8 tenta pausar **temporariamente** o LocalScript `Workspace.<jogador>.camera` quando V8 esta ON com multiplicador diferente de 1.0, e posiciona a camera usando o deslocamento do dedo direito em `RenderPriority=199`, preservando o script `bodyrotation`. Uma verificacao em 201 detecta se outro controlador sobrescreveu a camera e desativa V8 se necessario. A camera original volta quando usar OFF, X ou 1.0x.

**Calibracao estimada:** 0.9167 grau/pixel no viewport 724x375, observada nos X9/X11; pode diferir de outras circunstancias. Botao `X invertido`/`Y invertido` permite corrigir direcao se necessaria. O recorte horizontal (>43%) identifica de modo aproximado a area de camera, nao todos os controles do jogo.

**LIMITES:** V8 substitui temporariamente o controlador nativo de camera: efeitos de camera do jogo (oclusao, bob, emotes, transicoes e scripts que dependem do controlador) podem nao ser reproduzidos. `LocalScript.Enabled=false` pode nao parar callbacks em algumas condicoes; para isso existe deteccao de conflito, mas ela nao garante recuperar todo estado. A interface V8 tem ON/OFF, 0.1x/0.5x/1.0x/2.0x, slider e X/Y invert. O codigo nunca escreve `HumanoidRootPart.CFrame` nem altera a movimentacao.

**Loader V8 sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/memedash_sensibilidade_v8_controlador.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

Os arquivos de V5/V6/V7 e X9/X10/X11 continuam preservados.

## MemeDash V8.1: camera 0,1x-2,0x + sincronizacao do corpo (experimental)

O usuario testou V8 e confirmou que a camera ficou de fato mais rapida em 2x e mais lenta em 0.5x, porem o corpo do personagem permaneceu orientado na direcao antiga enquanto a camera girava. V8.1 se baseia na V8 original, **preservada em `memedash_sensibilidade_v8_controlador.lua` sem alteracoes**, e adiciona sincronizacao de yaw do personagem como prototipo separado.

V8.1 usa o proprio yaw calculado pela V8 a partir de TouchMoved; guarda o offset horizontal original entre o personagem e a camera no momento de ativacao. Depois da janela 199-201 detectada no X11, o codigo aplica uma correcao de yaw na `HumanoidRootPart.CFrame` na prioridade 205, preservando a posicao e a inclinacao atuais da raiz. A camera **nao le de volta o yaw do corpo**, reduzindo o risco do antigo ciclo de feedback. Sem escrita de posicao, velocidade, WalkSpeed, AutoRotate ou joystick. O sistema do jogo pode disputar a rotacao da raiz, portanto e um teste, nao resultado confirmado.

Botao **CORPO ON/OFF** permite desligar apenas a sincronizacao do personagem mantendo a camera V8 funcionando. **OFF, 1.0x ou X** desligam a camera alternativa e tentam religar o LocalScript original. A sincronizacao pula estados sentados, ancorados, sem humanoid ativo e camera/character invalida. Ao fazer OFF ou fechar, reentre no jogo se o controlador original nao voltar ao normal.

**Loader V8.1 sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/memedash_sensibilidade_v8_1_corpo.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```

Teste recomendado: reentrar no MemeDash sem V8 antiga ativa, executar V8.1, ligar 0.5x e 2x com CORPO ON; verificar se o avatar gira junto sem atrapalhar movimento. Se houver conflito, CORPO OFF e, se necessario, sair/reentrar. Nenhum script legado foi excluido.

## V8.2: orientacao invertida do personagem (experimental)

Depois de testar V8.1, usuario confirmou que a camera em 2x e 0.5x mudou de velocidade e que o corpo passou a acompanhar, mas comentou que 'o bagui ta ao contrario'. Como essa frase pode significar personagem de costas (deslocamento de 180 graus) ou giro espelhado, V8.2 oferece ambas as correcoes **independentes**, sem alterar o multiplicador de camera/touch herdado da V8.

`FRENTE +180` vem ligado por padrao e aplica 180 graus ao yaw-alvo do corpo; tocar nele alterna para `FRENTE 0` (igual ao alinhamento anterior). `GIRO NORMAL` vem ligado por padrao e pode ser alternado para `GIRO INV` (o giro horizontal do corpo passa a ter sinal contrario ao giro da camera). Ao alternar o sentido do giro, V8.2 recalibra os angulos de referencia para evitar giro brusco imediato. Os botoes preexistentes `X normal/invertido` e `Y normal/invertido` continuam afetando a camera e o toque, nao apenas o corpo. `CORPO ON/OFF` continua disponivel.

V8.2 ainda e experimental, pois sincroniza o corpo com escrita de orientacao na `HumanoidRootPart.CFrame` (mantendo a posicao). Isso pode conflitar com fisica, controle de movimento ou outros scripts; se houver problema use CORPO OFF, OFF/X e reentre se necessario. V8/V8.1 preservadas sem alteracoes.

**Loader V8.2 sem cache:**

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hshsagaga1-commits/-sensibilidade-memedash/main/memedash_sensibilidade_v8_2_direcao.lua?nocache=" .. tostring(os.time()) .. tostring(math.random(100000,999999)), true))()
```
