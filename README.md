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
