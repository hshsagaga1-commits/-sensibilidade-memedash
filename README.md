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
