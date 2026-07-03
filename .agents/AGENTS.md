# Regras do Projeto (AGENTS.md)

Este arquivo contém as regras e diretrizes para o desenvolvimento da aplicação.

## Diretrizes Gerais
- **Nome do App**: O nome da aplicação é **ilithid**.
- Manter o código limpo, legível e bem documentado.
- Seguir os padrões e convenções da linguagem do projeto.
- **Idioma**: Todo o código (variáveis, comentários, funções, classes, etc.) deve ser escrito em **Inglês**.
- **Credenciais**: Utilizar as credenciais especificadas no arquivo [credentials.md](file:///mnt/ssd/projetos/rpg_helper/docs/credentials.md).
- **Configurações e Env**: Usar arquivo `.env` (que deve ser ignorado no `.gitignore`) para armazenar dados sensíveis (como chaves de API) e URLs de endpoints de servidores. Esses valores devem ser carregados em tempo de compilação (ex: via `String.fromEnvironment` / `--dart-define-from-file`) para gerar os artefatos de build.
- **Boas Práticas**: Seguir as boas práticas recomendadas de Flutter.

## Arquitetura do Projeto
- **Feature Layer**: A estrutura de pastas deve seguir uma arquitetura orientada a features para melhor modularidade.
- **Shared/Compartilhado**:
  - Código reutilizado/repetido deve ser movido para a pasta `shared`.
  - A pasta `shared` deve ser organizada por domínios de atuação (ex: `shared/components`, `shared/services`, etc.).

## Workflow & Processos
- **Novas Regras / New Rules**: Quando for solicitado adicionar novas regras, utilize e atualize sempre o arquivo [AGENTS.md](file:///mnt/ssd/projetos/rpg_helper/.agents/AGENTS.md).
- **Novas Features / New Features**: Quando for solicitado adicionar uma nova feature, deve ser criada uma nova task no GitHub Projects.
- **Gestão de Tarefas (GitHub Projects)**:
  - **CRÍTICO**: Ao iniciar o desenvolvimento de qualquer tarefa/issue, o status da mesma no GitHub Projects deve ser **IMEDIATAMENTE** alterado para **In Progress** (Em progresso), antes de qualquer modificação de código ser iniciada.
  - **CRÍTICO**: O assistente deve atualizar obrigatoriamente as checklists/subtasks (marcar `- [x]`) no corpo das issues correspondentes no GitHub assim que cada feito ou subtask for concluída, de modo que o usuário saiba exatamente o que já foi entregue.
  - A issue em si e o card no board não devem ser fechados ou movidos para o status **Done** (Concluído) pelo assistente, deixando essa etapa de verificação e encerramento para o usuário.
- **Execução do Aplicativo (Hot Reload)**: Ao iniciar o desenvolvimento de qualquer tarefa, o assistente deve verificar se o aplicativo está rodando em segundo plano (em Web e Android). Caso não esteja, deve iniciar a execução do aplicativo (abrindo o emulador Android se necessário) para permitir feedback visual rápido e Hot Reloads automáticos.
- **Estratégia de Branching (GitHub Flow)**:

  - Todo desenvolvimento deve ser feito em branches ramificadas a partir da `main` (ex: `feature/nome-da-feature`).
  - O merge na branch `main` deve ser realizado exclusivamente via Pull Requests.
  - A branch `main` sempre deve conter um estado estável pronto para produção.
  - **Labels em Pull Requests**: Todos os Pull Requests criados devem conter obrigatoriamente as labels correspondentes ao tipo de alteração (ex: `feature`, `bug`, `chore`, `documentation`, `tests`).
  - **Abertura de Pull Requests**: O assistente de IA nunca deve criar ou abrir um Pull Request no GitHub automaticamente. A abertura de qualquer Pull Request deve ser autorizada explicitamente pelo usuário.
- **Versões de Dependências**: Sempre busque e utilize as versões estáveis mais atualizadas de pacotes e dependências de terceiros (ex: dependências no `pubspec.yaml`, ações/workflows do GitHub Actions, etc.).




## Diretrizes de Teste
- **Testes Unitários**: Para cada iteração do sistema, deve ser criado obrigatoriamente um teste unitário para validação de regras de negócio.
- **Testes E2E (End-to-End)**:
  - Devem ser executados antes de realizar qualquer commit.
  - Podem ser estruturados e criados por Epics (não há necessidade de cobrir E2E para absolutamente tudo, focando nos fluxos críticos).
- **Interfaces Web**: Em interfaces Web, utilize testes de integração e validação.

## Formatação & Qualidade de Código (Linting)
- **Formatação de Código**: Todo código fonte gerado ou modificado deve obrigatoriamente ser formatado utilizando o comando `dart format .` antes de ser commitado.
- **Análise Estática Rigorosa**: O linter do Dart (`flutter analyze`) deve rodar com sucesso em ambiente local, sem apresentar erros ou avisos (warnings), em total conformidade com as regras configuradas no `analysis_options.yaml`.
- **Prevenção de Quebras de CI**: A verificação de formatação e análise estática deve ser executada localmente antes da abertura ou atualização de qualquer Pull Request (evitando quebras do workflow de CI).



