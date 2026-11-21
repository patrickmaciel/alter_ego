# README_LOCAL — notas do fork (build e instalação no Windows)

Notas pessoais deste fork do Alter Ego. O `README.md` original descreve o build para Linux
com MinGW; aqui está o que funcionou de fato no Windows 11 + WSL e as armadilhas encontradas.

## Mudança feita neste fork

**Aba Characters → botão Refresh** (`src/dllmain.cpp`, bloco "Refresh Characters button + status"):

- **Refresh** agora atualiza **somente o personagem selecionado** (chama
  `GW2API::RequestCharacterRefreshSelected({nome})`). Sem personagem selecionado, carrega
  a lista de personagens como antes.
- Botão **`...`** ao lado abre o popup antigo ("Select Characters to Refresh"), para
  atualizar vários personagens ou todos.
- Nenhuma alteração foi necessária no fork do Hoard & Seek (`C:\w\hoard_and_seek`).

Também: `src/GW2API.h` ganhou `#include <atomic>` (o clang exige; o GCC pegava por inclusão indireta).

## Como funciona a atualização (para futuras mudanças)

- O Alter Ego **não** chama a API do GW2 para dados de personagem. Ele pede ao addon
  **Hoard & Seek (H&S)** via eventos do Nexus (`EV_HOARD_QUERY_API`), endpoint por endpoint
  (`/core`, `/equipmenttabs`, `/equipment`, `/buildtabs`, `/crafting`, `/heropoints`).
  Ver `GW2API::FetchCharacterPhase`.
- O H&S guarda um **cache de 30 s** por (conta, endpoint) (`ProxyThrottle`,
  `CACHE_TTL_SECONDS`). Dois refreshes seguidos do mesmo personagem podem devolver o cache.
- `Events_Raise` é síncrono: nunca segurar mutex ao chamá-lo (ver `include/HoardAndSeekAPI.h`).

## Armadilha crítica: runtime C (UCRT vs msvcrt)

O AE faz `delete` em respostas alocadas com `new` dentro do H&S (cruzam a fronteira entre
DLLs). **As duas DLLs precisam usar o mesmo runtime C: UCRT.**

- O `mingw-w64` do Ubuntu 22.04 (`apt install mingw-w64`, GCC 10) usa **msvcrt** →
  compila, carrega, mas **o jogo crasha ao abrir o addon** com `0xc0000374`
  (corrupção de heap, módulo `ntdll.dll`).
- Para conferir o runtime de uma DLL, procure por `api-ms-win-crt-*` (UCRT, correto) em vez
  de `msvcrt.dll` nos imports. Compare com `Hoard__Seek.dll`.
- O `debug.log` na pasta do GW2 é ruído do navegador interno do jogo; o crash real aparece
  no Event Viewer (Aplicativo, ID 1000, `Gw2-64.exe`).

## Como compilar (Windows + WSL Ubuntu-22.04 + llvm-mingw UCRT)

### Preparação (uma vez)

```powershell
# cmake e make dentro do WSL
wsl -d Ubuntu-22.04 -u root -- apt-get install -y cmake make

# toolchain llvm-mingw com UCRT (~84 MB), instalado em ~/llvm-mingw
wsl -d Ubuntu-22.04 -- bash -c "cd ~ && curl -sL -o llvm-mingw.tar.xz https://github.com/mstorsjo/llvm-mingw/releases/download/20261117/llvm-mingw-20261117-ucrt-ubuntu-22.04-x86_64.tar.xz && mkdir -p llvm-mingw && tar xf llvm-mingw.tar.xz -C llvm-mingw --strip-components=1"
```

O `CMakeLists.txt` fixa os nomes `x86_64-w64-mingw32-gcc/g++/windres`; o llvm-mingw fornece
esses nomes (apontando para clang), basta colocá-lo primeiro no `PATH`.

### Script de build

O script versionado é [`tools/wsl_build.sh`](tools/wsl_build.sh). Ele compila em
`~/ae_build2` (dentro do WSL, mais rápido que `/mnt/c`) e copia o resultado para
`build/AlterEgo.dll`. O `PATH` é limpo de propósito: o PATH herdado do Windows tem
parênteses/espaços que quebram o `bash -c`.

### Compilar

Rode **pelo PowerShell** (no Git Bash o caminho `/mnt/c/...` é reescrito e falha):

```powershell
wsl -d Ubuntu-22.04 -- bash /mnt/c/w/alter_ego/tools/wsl_build.sh
```

Saída: `C:\w\alter_ego\build\AlterEgo.dll` (~2,9 MB). O tamanho não bate exatamente com
builds antigos feitos com GCC; isso é normal.

## Como instalar no jogo

1. Feche o Guild Wars 2 (a DLL fica bloqueada com o jogo aberto).
2. Faça backup: `Alter_Ego.dll` → `Alter_Ego.dll_backup` (em `C:\Program Files\Guild Wars 2\addons`).
3. Copie (PowerShell como administrador):

   ```powershell
   Copy-Item "C:\w\alter_ego\build\AlterEgo.dll" "C:\Program Files\Guild Wars 2\addons\Alter_Ego.dll" -Force
   ```

4. Abra o jogo. **Não mexa** em `addons\AlterEgo\` — é a pasta de dados (settings,
   `characters.json`, `build_library.json`, caches), não faz parte do build.

Nota: no jogo o arquivo se chama `Alter_Ego.dll` (nome do Nexus), enquanto o build gera
`AlterEgo.dll`.

## Se o jogo crashar ao abrir o addon

```powershell
Get-WinEvent -FilterHashtable @{LogName='Application';Id=1000} -MaxEvents 1 | Format-List Message
```

- `0xc0000374` → heap corrompido; quase certamente mistura de runtime (ver seção UCRT).
- Restaure o backup para voltar ao estado anterior.
