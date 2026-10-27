# Ações manuais

## Antes de rodar no iPad
1. `cp Config/Local.xcconfig.example Config/Local.xcconfig` e preencha `DEVELOPMENT_TEAM` com o seu Team ID (Xcode → Settings → Accounts, ou developer.apple.com → Membership).
2. `make project` e abra `Agacha.xcodeproj`.
3. Conecte o iPad mini 6, confie no computador e ative **Ajustes → Privacidade e Segurança → Modo Desenvolvedor**.
4. Escolha o iPad como destino e rode (⌘R). Na primeira vez, aceite a permissão da câmera.
5. Se aparecer "Untrusted Developer": Ajustes → Geral → VPN e Gerenciamento de Dispositivo.

## Gravar fixtures (Fase 0)
Só são salvos **esqueletos em JSON**, nunca imagens. Em cada gravação, escreva a situação em *Ajustes → Notas*.
1. **1 pessoa**, 10–15 s: de pé → agacha → de pé, alternando a cada ~2 s.
2. **3 pessoas**, 10–15 s: todas fazem juntas e depois uma de cada vez.
3. **5 pessoas**, 10–15 s: igual.
Toque em *Recalibrar* com todos em pé antes de começar, depois em *Gravar fixture*; ao terminar, *Parar*.
Pegue os arquivos no app **Arquivos → No meu iPad → Agacha** e copie para `Fixtures/`.

## Mais adiante
- Fase 1: nenhuma além do Team ID.
- Fase 2: exportar `docs/mocks/` (já feito), fornecer os `.riv` e fontes Baloo 2/Nunito (OFL).
- Fase 3: App ID, capabilities (In-App Purchase), produto "Pacote Família" no App Store Connect, acordo de apps pagos.
