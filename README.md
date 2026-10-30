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
