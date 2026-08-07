---
name: pausar-trabalho
description: Salva um resumo do que está em andamento no projeto atual, pra continuar depois — no mesmo perfil, em outro perfil (.claude/.claude-work), ou até em outra ferramenta (Antigravity). Use quando o usuário disser /pausar-trabalho ou pedir explicitamente pra pausar ou guardar o progresso.
---

# pausar-trabalho

Grava um checkpoint do trabalho em andamento no diretório atual, pra retomar
depois com `/continuar-trabalho`.

## Passos

1. Monte um resumo em texto corrido (sem precisar de seções rotuladas) do
   que está em andamento: a tarefa atual, o que já foi feito até agora, os
   próximos passos concretos, e os arquivos principais tocados. Seja
   específico o bastante pra alguém sem memória desta conversa conseguir
   continuar a partir só desse texto.
2. Rode, com o resumo do passo 1 no stdin:
   ```bash
   node ~/agentes-pipeline/claude/continuidade/core/state.js save \
     --cwd "$(pwd)" <<'EOF'
   <resumo do passo 1>
   EOF
   ```
   (Se você souber o `session_id` da sessão atual, inclua
   `--session-id "<id>"` no comando — se não souber, pode omitir.)
3. Confirme pro usuário, em uma frase curta, que o progresso foi salvo e que
   ele pode retomar depois com `/continuar-trabalho` — no mesmo lugar, em
   outro perfil, ou em outra ferramenta, desde que seja o mesmo diretório de
   projeto.
