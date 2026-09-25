# Modelos e subagentes

Carregado sob demanda: o Orquestrador consulta esta tabela ao montar cada
disparo; uma persona só precisa abrir este arquivo se for disparar
subagentes próprios.

## Regra

**Sempre passe `model` explicitamente** em todo disparo de subagente
(`"haiku"`, `"sonnet"` ou `"opus"`) — nunca dependa do default da
ferramenta, que herda o modelo da sessão principal e não é garantido.

| Modelo | Quem roda nele |
|--------|----------------|
| `haiku` | Triagem mecânica, `/orquestrador-team`, `/orquestrador-status`, varredura por projeto do `/orquestrador-init` |
| `sonnet` | Analista, PO, BDD, Designer, TL, Dev, QA, Revisor rápido (completo), lentes do Revisor, verificador do Revisor fora de `critical`, Segurança fora de `critical`, turnos do Grill e do Orquestrador-Design, especialistas de design (UX, Brand, Copywriter, Acessibilidade, Dev-Design), Avaliador no modo padrão, protótipos do `/orquestrador-plan` |
| `opus` | Arquiteto (inclusive OPÇÕES do `/orquestrador-plan`), verificador do Revisor em tier `critical`, Segurança em tier `critical`, `DESAFIANTE` e `AVALIADOR` em modo duelo (modo "Me Surpreenda") |

- **Escalonamento:** subir um degrau (sonnet → opus) só com motivo
  registrado — ex.: a mesma etapa não convergiu na 2ª volta por limitação
  de raciocínio, ou o usuário pediu. Avise o usuário ao escalar.
- **Ressalva de fork:** o override de modelo não funciona ao disparar um
  *fork* — um fork sempre roda no modelo de quem o disparou. Etapas do
  pipeline são sempre subagentes novos (`subagent_type: general-purpose`),
  nunca fork.
- No modo "Me Surpreenda" do Time de Design, `DESAFIANTE` e `AVALIADOR` em
  modo duelo sempre rodam em Opus — passe `model` explicitamente no disparo.

## Subagentes próprios

Qualquer agente deste pipeline pode disparar subagentes próprios para
paralelizar partes independentes do seu trabalho, seguindo a mesma tabela
(na dúvida, `sonnet`) e passando `model` explicitamente.
