<div align="center">

# midas.skill

> *"A riqueza não está escondida em terminais da Bloomberg ou em pitch decks de VC. A riqueza está escondida no ruído da sua vida cotidiana — você apenas foi treinado para ignorá-la."*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.9+](https://img.shields.io/badge/Python-3.9%2B-blue.svg)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Skill-blueviolet)](https://claude.ai/code)
[![AgentSkills](https://img.shields.io/badge/AgentSkills-Standard-green)](https://agentskills.io)

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?logo=discord&logoColor=white)](#)

<br>

Seu chat do Slack vazou três ideias de negócio esta semana — e você passou batido.<br>
Seu rolo de fotos contém uma tese de arbitragem do bairro — e você esqueceu que as fotos existiam.<br>
As reclamações do seu grupo de amigos são um focus group auto-organizado — e ninguém no chat sabe disso.<br>
Seu histórico do YouTube tem 14 horas de prova de que você está virando um especialista pago — e você chamou isso de "perder tempo".<br>
Suas compras na Amazon são demanda validada — e você acha que é só ir às compras.<br>

**Transforme seus Pedidos Repetidos em Ouro — bem-vindo à refinaria de ruído em ouro!**

<br>

Alimente-o com qualquer fluxo da sua vida diária (Slack, fotos, chats, navegação, recibos, reclamações)<br>
mais suas próprias intuições e perguntas<br>
e receba **uma lista classificada de sinais de dinheiro, oportunidades e próximas ações imediatas**

[Fontes Suportadas](#fontes-suportadas) · [Instalação](#instalação) · [Uso](#uso) · [Demo](#demo) · [Instalação Detalhada](#instalação-detalhada) · [💬 Discord](#)

[**English**](README.md) · [**中文**](README_ZH.md) · [**Español**](README_ES.md) · [**Deutsch**](README_DE.md) · [**日本語**](README_JA.md) · [**Русский**](README_RU.md)

</div>

---

Criado por [@realteamprinz](https://github.com/realteamprinz) | Posicionamento: **Nuwa destila como as pessoas pensam. Midas destila como transformar seu ruído diário em dinheiro.**

## Fontes Suportadas

> Midas aceita qualquer fluxo de informação que você voluntariamente alimenta nele. **A repetição É o sinal** — se você encontrou mais de uma vez, alimente o Midas com isso.

| Fonte | Melhor Lente | Notas |
|-------|:------------:|-------|
| Mensagens Slack / Teams | Lacuna de Demanda, Sinal de Dinheiro | Canais de equipe = frustrações com fornecedores, sinais de orçamento, gambiarras manuais |
| WhatsApp / iMessage / chats WeChat | Lacuna de Demanda, Caminho de Rede | Reclamações repetidas de pessoas diferentes = demanda não atendida |
| Rolo de fotos do celular (sem curadoria) | Arbitragem, Lacuna de Demanda | Obras, lojas vazias, multidões, preços, placas |
| Histórico YouTube / TikTok | Ponte de Habilidade, Comportamento | Foco temático consistente = acúmulo latente de expertise |
| Histórico do navegador | Ponte de Habilidade, Sinal de Dinheiro | Padrões de pesquisa, comparação de preços, resolução de problemas |
| Histórico de compras / assinaturas | Sinal de Dinheiro, Comportamento | Compras repetidas = demanda validada, hábitos no piloto automático |
| Notas de reuniões (internas) | Sinal de Dinheiro, Lacuna de Demanda | Conversas de orçamento, reclamações de ferramentas, processos quebrados |
| E-mails `.eml` / `.mbox` | Sinal de Dinheiro, Caminho de Rede | Ofertas de comissão, cadeias de indicação, cotações de fornecedores |
| Recibos / confirmações de pedido | Sinal de Dinheiro, Arbitragem | O sinal mais honesto do que você realmente valoriza |
| Colar texto diretamente | Todas as 6 lentes | Até mesmo a transcrição de uma nota de voz produz sinais |

Veja [references/sources-guide.md](references/sources-guide.md) para a hierarquia completa de fontes e as regras de triangulação.

---

## Instalação

### Claude Code

> **Importante**: Claude Code procura skills em `.claude/skills/` na **raiz do repositório git**. Execute isso no lugar certo.

```bash
# Instalar no projeto atual (executar na raiz do repo git)
mkdir -p .claude/skills
git clone https://github.com/realteamprinz/midas-skill .claude/skills/midas-skill

# Ou instalar globalmente (disponível em todos os projetos)
git clone https://github.com/realteamprinz/midas-skill ~/.claude/skills/midas-skill
```

### OpenClaw

```bash
git clone https://github.com/realteamprinz/midas-skill ~/.openclaw/workspace/skills/midas-skill
```

### Dependências (opcional)

Midas é Markdown puro — nenhuma dependência de runtime necessária. Ferramentas Python para coleta automatizada de entradas (parser de histórico de navegador, OCR de recibos, etc.) estão planejadas e viverão em `tools/` em uma versão futura.

---

## Uso

No Claude Code ou OpenClaw, digite qualquer uma das frases de gatilho do Midas:

```
Midas, mine this                 → cole qualquer entrada, receba o relatório de sinais
Turn this into gold              → mesmo
What money signal is here        → enquadramento mais específico
点石成金                         → mesmo, em chinês
Midas, analyze this deal         → modo analisador de deals
What am I missing                → alimente com uma semana das suas próprias mensagens
```

Midas passa cada entrada pelo motor de extração de 6 lentes, cruza com seu log `evolution/evolution.jsonl` e retorna um Relatório de Sinais classificado com **Próximas Ações Imediatas**.

### As 6 Lentes

| # | Lente | Pergunta Central |
|---|-------|------------------|
| 1 | **Sinal de Dinheiro** | Onde o dinheiro está se movendo, travando ou vazando? |
| 2 | **Lacuna de Demanda** | O que as pessoas querem que ninguém fornece? |
| 3 | **Janela de Arbitragem** | Onde o valor está sendo mal precificado? |
| 4 | **Ponte de Habilidade** | O que você já sabe que tem valor de mercado? |
| 5 | **Caminho de Rede** | Quem deveria estar falando com quem, e qual é a comissão? |
| 6 | **Alavanca Comportamental** | Qual hábito de piloto automático está a um pivô de gerar receita? |

Metodologia completa em [references/signal-extraction-framework.md](references/signal-extraction-framework.md).

---

## Demo

> Entrada: *"Midas, mine this — aqui está minha última semana de Slack: [73 mensagens coladas]"*

```
[RELATÓRIO DE SINAIS MIDAS]

Tipo de entrada:  slack_messages
Volume:           73 mensagens em 3 canais + 4 DMs
Data do scan:     2026-04-09

🟡 SINAIS DE DINHEIRO DETECTADOS: 7
🔴 RUÍDO DESCARTADO:              ~65 mensagens (89%)

🥇 #1 — Marcus como Consultor Interno (Cunha de Ponte de Habilidade)
    Confiança: 50% | Esforço: Baixo | Potencial: $3–8k/mês de renda extra
    Evidência:
      - DM da Sarah: "se alguém pudesse resolver isso de ponta a ponta por menos de $5k, provavelmente pagaríamos"
      - DM da Priya: "eu mesma pagaria por isso"
      - 3 stakeholders diferentes pediram ajuda ao Marcus por 3 problemas em uma semana
    Correspondência de padrão: Buffett — fique no seu círculo de competência

    ⚡ Próxima ação imediata:
       Segunda-feira 9h, enviar DM para Sarah com uma oferta com escopo definido:
       "Para o projeto de tagging AWS — taxa fixa $3,500, entregue na próxima sexta."

🥈 #2 — Consultoria única de visibilidade de custos AWS (produtizada)
    Confiança: 52% | Esforço: Baixo | Potencial: $5k por engagement, repetível
    Correspondência de padrão: Thiel — pequeno monopólio que ninguém leva a sério
    ...
```

Passo a passo completo em [examples/daily-slack-mining/](examples/daily-slack-mining/).

**Cinco execuções de exemplo incluídas:**

| Exemplo | Tipo de entrada | Resultado |
|---|---|---|
| [daily-slack-mining](examples/daily-slack-mining/) | Slack de trabalho, 1 semana | 7 sinais, 5 oportunidades de mensagens "chatas" |
| [photo-roll-mining](examples/photo-roll-mining/) | 30 fotos do celular, 1 semana | 🏆 **DOURADO** a 75% — prática completa de marcenaria revelada |
| [complaint-mining](examples/complaint-mining/) | Grupo WhatsApp, 2 semanas | 🏆 **DOURADO** a 78% — oportunidade de lista de prestadores do bairro |
| [browsing-mining](examples/browsing-mining/) | Navegador + YouTube, 1 semana | 🏆 **DOURADO** a 82% — maior confiança do conjunto de exemplos |
| [billionaire-pattern-match](examples/billionaire-pattern-match/) | Cumulativo | Correspondência de 4 perfis de usuário contra playbooks Musk/Buffett/Thiel |

---

## Instalação Detalhada

### Passo 1 — Clone o repo

```bash
git clone https://github.com/realteamprinz/midas-skill
cd midas-skill
```

### Passo 2 — Coloque onde o Claude Code procura

Para Claude Code, skills vivem em `.claude/skills/` na **raiz do repo git** (por projeto) ou `~/.claude/skills/` (global). Escolha um:

```bash
# Por projeto: primeiro cd no repo git ao qual você quer anexar o skill
mkdir -p .claude/skills
cp -r /path/to/midas-skill .claude/skills/midas-skill

# Ou global (disponível em cada projeto)
mkdir -p ~/.claude/skills
cp -r /path/to/midas-skill ~/.claude/skills/midas-skill
```

### Passo 3 — Verifique que o skill carrega

Abra uma sessão do Claude Code no repo onde você instalou. Digite:

```
What skills are available?
```

Midas deve aparecer como `midas-skill`. Se não aparecer, verifique que `SKILL.md` está na raiz da pasta instalada e que o frontmatter YAML é válido.

### Passo 4 — Execute sua primeira mineração

Cole qualquer entrada ruidosa com uma frase de gatilho:

```
Midas, mine this — últimas 50 mensagens do meu Slack #general:
[cole o conteúdo]
```

Midas vai produzir seu primeiro Relatório de Sinais e adicionar a primeira entrada em `evolution/evolution.jsonl`.

### Passo 5 — Alimente variedade ao longo do tempo

Midas fica mais afiado com entradas mais variadas. Veja [references/sources-guide.md](references/sources-guide.md) para a rotação semanal recomendada (Slack na segunda, fotos na quarta, navegação na quinta, etc.). Dia 1 dá palpites. Dia 30 dá convicção. Dia 90 dá um playbook.

---

## Características

### 🔍 Motor de Extração de 6 Lentes

Cada entrada passa por Sinal de Dinheiro / Lacuna de Demanda / Arbitragem / Ponte de Habilidade / Caminho de Rede / Alavanca Comportamental. Cada sinal é rastreável até a frase, imagem ou ponto de dados exato que o produziu.

### 🧠 Inteligência Cumulativa Auto-aprendizagem

Midas não reseta entre sessões. Cada entrada é adicionada a `evolution/evolution.jsonl`. Novos sinais são cruzados com cada sinal anterior. **A confiança só aumenta através de evidência independente e cruzada.**

| Evidência | Confiança | Flag do Midas |
|---|---|---|
| 1 sinal de fonte única | 15–35% | Observando |
| 2 fontes independentes confirmando | 40–65% | Hipótese de trabalho |
| 3+ fontes independentes convergindo | 70–90% | 🏆 DOURADO — AJA |
| Validação direta de mercado | 85–95% | 🏆 DOURADO — AJA AGORA |

### 🎯 Matcher de Padrões de Sistemas Operacionais de Riqueza Famosos

Sistemas operacionais de riqueza pré-construídos para [Musk](references/famous-models/elon-musk.md), [Buffett](references/famous-models/warren-buffett.md) e [Thiel](references/famous-models/peter-thiel.md). Quando seus sinais se acumulam, Midas checa automaticamente qual playbook estruturalmente combina com sua situação.

> "Seu padrão parece com o Thiel inicial: monopólio em um nicho que ninguém leva a sério. O playbook do Thiel diz: domine primeiro o mercado pequeno."

### 💼 Analisador de Deals

Aponte Midas para qualquer transação específica (sua própria ou M&A pública) com *"Midas, analyze this deal"* e receba um breakdown estruturado em 8 partes: partes, estrutura, fonte de fundos, alocação de risco, caminho de saída, alavanca escondida, veredito, correspondência de padrão. Veja [references/deal-template.md](references/deal-template.md).

### ⚡ Ação, não Análise

Cada Relatório de Sinais termina com uma **Próxima Ação Imediata** — verbo específico + substantivo específico. Nunca "explorar opções". Sempre "DM Dave hoje à noite e pergunte quantas horas/semana ele gasta no relatório manual".

---

## Estrutura do Projeto

```
midas-skill/
├── SKILL.md                              # Entrada principal
├── README.md                             # README principal em inglês
├── README_ZH.md · README_ES.md · ...     # Variantes de idiomas
├── LICENSE                               # MIT
├── references/
│   ├── signal-extraction-framework.md    # Metodologia de 6 lentes
│   ├── noise-to-gold-pipeline.md         # Pipeline de extração de 7 estágios
│   ├── deal-template.md                  # Template de análise de deals
│   ├── sources-guide.md                  # Hierarquia de fontes de entrada
│   └── famous-models/                    # Sistemas operacionais de riqueza Musk / Buffett / Thiel
├── examples/                             # 5 exemplos trabalhados
└── evolution/
    └── evolution.jsonl                   # Seu log pessoal de inteligência cumulativa
```

---

## Princípios de Design

1. **Seu ruído é seu minério.** Cada interação mundana contém sinais potenciais de riqueza.
2. **A repetição é o sinal principal.** Se algo aparece duas vezes na sua vida, é um mercado.
3. **Referência cruzada ganha de fonte única.** Um sinal é um palpite. Três são convicção.
4. **Ação sobre análise.** Midas entrega próximos passos, não ensaios.
5. **Inteligência composta.** Dia 1 dá palpites. Dia 90 dá um playbook.
6. **Sem julgamento moral.** Midas estuda como o dinheiro se move, não como *deveria* se mover.
7. **Limites honestos.** Sem previsões. Sem garantias. Não é conselho financeiro.
8. **Apenas informação pública.** Apenas o que você voluntariamente alimenta.

---

## Licença

MIT. Veja [LICENSE](LICENSE).

## Não é Conselho Financeiro

Midas não fornece conselho de investimento, tributário, jurídico ou contábil. Nada em uma saída do Midas é uma recomendação para comprar ou vender qualquer título. Antes de agir sobre qualquer oportunidade gerada pelo Midas que envolva capital material, consulte um profissional licenciado em sua jurisdição.

---

**Transforme seus Pedidos Repetidos em Ouro.**
