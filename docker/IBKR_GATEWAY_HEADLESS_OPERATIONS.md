# IBKR Gateway Headless Operations Guide

## Obiettivo

Procedura operativa per avviare e mantenere stabile IBKR Gateway in modalità headless con IBC, evitando la riscrittura di TrustedIPs, sbloccando il 2FA, prevenendo crash del processo Java e ripristinando un docker-compose valido.

---

## 1) Diagnostica immediata

Eseguire nell'ordine seguente.

### 1.1 Log Java del Gateway per capire il crash

```bash
docker exec gateway-headless sh -lc 'ls -ltr /app/ibkr/logs/ | tail -n 3'
docker exec gateway-headless sh -lc 'tail -n 400 /app/ibkr/logs/gateway_headless_*.log'
```

### 1.2 Stato del display virtuale e variabili d'ambiente

```bash
docker exec gateway-headless sh -lc 'echo DISPLAY=$DISPLAY; command -v Xvfb || which Xvfb; pgrep -a Xvfb'
```

### 1.3 Stato porta API 4001

```bash
docker exec gateway-headless sh -lc "ss -ltnp | awk '\$4 ~ /:4001$/ {print}' || true"
```

### 1.4 IBC log in tempo reale per 2FA

```bash
docker exec -it gateway-headless sh -lc 'tail -f /app/ibc/logs/ibc_output.log'
```

### 1.5 Watchdog TrustedIPs attivo e log

```bash
docker exec gateway-headless sh -lc 'pgrep -af fix_trusted_ips.sh || echo "watchdog non in esecuzione"'
docker exec gateway-headless sh -lc '[ -f /app/logs/trusted_ips_fix.log ] && tail -n 200 /app/logs/trusted_ips_fix.log || echo "log watchdog assente"'
```

---

## 2) Hot-fix: impedire che IBC riscriva TrustedIPs

Watchdog idempotente che forza il valore desiderato dopo ogni rewrite.

### 2.1 Script watchdog

Il watchdog script è disponibile in: `docker/common/ibkr_gateway/ibkr/fix_trusted_ips.sh`

Può essere eseguito in due modalità:
- **Modalità singola esecuzione**: Esegue il fix una sola volta e termina (comportamento attuale)
- **Modalità watchdog continuo**: Monitora continuamente e corregge automaticamente (attivabile con `--watch`)

Per abilitare il watchdog continuo, il script deve essere avviato con il parametro `--watch`:

```bash
chmod +x /usr/local/bin/fix_trusted_ips.sh
TRUSTED_CIDRS="127.0.0.1,172.20.0.0/16,10.0.0.0/8" nohup /usr/local/bin/fix_trusted_ips.sh --watch >/dev/null 2>&1 &
```

### 2.2 Configurazione TRUSTED_CIDRS

Il watchdog supporta la configurazione di TRUSTED_CIDRS tramite variabile d'ambiente:

```bash
export TRUSTED_CIDRS="127.0.0.1,172.20.0.0/16,10.0.0.0/8"
```

Se non specificata, usa il default: `172.20.0.0/16`

### 2.3 Alternative

* Bind-mount di `jts.ini` con valore corretto. Se read-only, alcune build IBC falliscono al rewrite. Watchdog resta preferibile.
* Riduci la superficie: consenti solo la subnet Docker realmente usata, per esempio `172.23.0.0/16`.

---

## 3) Crash del processo Java: cause tipiche e fix

Sintomi: il processo esce prima che l'API apra la porta 4001. Spesso mancano librerie X11, font, NSS o ci sono problemi col display virtuale.

### 3.1 Dipendenze a bordo container

Debian o Ubuntu:

```bash
apt-get update && apt-get install -y \
  xvfb xauth x11-apps fonts-dejavu fonts-liberation \
  libnss3 libxrender1 libxtst6 libxi6 libxrandr2 libxcomposite1 \
  libasound2 ca-certificates
```

Alpine:

```bash
apk add --no-cache \
  xvfb xauth font-dejavu nss libxrender libxtst libxi libxrandr libxcomposite \
  alsa-lib ca-certificates
```

### 3.2 Display virtuale

```bash
Xvfb :1 -screen 0 1024x768x24 &
export DISPLAY=:1
```

Assicurarsi che il lancio del Gateway avvenga solo dopo l'avvio di Xvfb.

---

## 4) 2FA: sblocco e automazione

Percorso minimo: approvare manualmente la push su IBKR Mobile quando IBC mostra "Second Factor Authentication". Tenere in tail il log IBC:

```bash
docker exec -it gateway-headless sh -lc 'tail -f /app/ibc/logs/ibc_output.log'
```

### Opzionale TOTP automatizzato (valutare rischi)

* Abilitare un metodo TOTP secondario sull'account.
* Esporre il segreto come variabile di ambiente `OTP_SECRET` solo a runtime.
* Generare all'occorrenza un codice:

```bash
oathtool --totp -b "$OTP_SECRET"
```

**Note**

* Alcune versioni di IBC supportano TOTP via config. In caso contrario, orchestrare l'inserimento con expect o un piccolo wrapper che inoltra il codice verso l'input del dialog IBC.

---

## 5) Porta 4001: readiness e healthcheck

Compose healthcheck che diventa healthy solo quando 4001 è in LISTEN.

```yaml
healthcheck:
  test: ["CMD-SHELL", "ss -lnt | grep -q ':4001'"]
  interval: 10s
  timeout: 3s
  retries: 18
  start_period: 120s
```

Attendere readiness prima di far connettere servizi dipendenti, per esempio con un wait-loop in entrypoint:

```bash
timeout 180 sh -c 'until ss -lnt | grep -q ":4001"; do sleep 2; done'
```

---

## 6) ib_insync: handshake solo a gateway pronto

Snippet di prova lato microservizio execution:

```python
from ib_insync import IB
ib = IB()
ib.connect('gateway-headless', 4001, clientId=5, readonly=False)
ib.reqCurrentTime()
print('Connected:', ib.isConnected())
ib.disconnect()
```

---

## 7) docker-compose: esempio corretto e hardening

Errore tipico YAML: valori con due punti o slash non quotati. Esempio minimale pulito disponibile in:
`docker/docker-compose.example.yml`

Validare prima di usare:

```bash
yamllint docker-compose.yml
```

### Variabili d'ambiente supportate

* `IB_USER`: Username Interactive Brokers
* `IB_PASSWORD`: Password Interactive Brokers
* `TRADING_MODE`: `paper` o `live`
* `DISPLAY`: Display virtuale per Xvfb (default: `:1`)
* `TRUSTED_CIDRS`: Subnet consentite per API (default: `172.20.0.0/16`)
* `OTP_SECRET`: Segreto TOTP per 2FA automatico (opzionale)
* `WATCHDOG_ENABLED`: Abilita watchdog continuo TrustedIPs (default: `false`)

---

## 8) Sequenza operativa raccomandata

1. Correggere e validare `docker-compose.yml`.
2. Abilitare il watchdog TrustedIPs se necessario.
3. Avviare Xvfb e impostare `DISPLAY` correttamente.
4. Avviare il Gateway e seguire `ibc_output.log` per approvare il 2FA.
5. Attendere healthcheck su 4001, quindi testare con `ib_insync`.
6. Se il Java crasha ancora, installare librerie mancanti e ripetere la diagnosi su `/app/ibkr/logs/…`.

---

## 9) Hardening e sicurezza

* Limitare `TRUSTED_CIDRS` alla sola subnet dei container che devono collegarsi.
* Evitare di esporre 4001 all'host quando non necessario; preferire la rete Docker condivisa.
* Se si usa TOTP, non committare mai il segreto; usare secret manager o variabili runtime.
* Utilizzare restart policy `unless-stopped` per evitare loop di restart in caso di problemi di configurazione.

---

## 10) Checklist rapida

- [ ] TrustedIPs resta quello impostato dopo l'avvio
- [ ] Xvfb attivo e `DISPLAY` valorizzato
- [ ] 2FA approvata o TOTP funzionante
- [ ] Porta 4001 in LISTEN e container `healthy`
- [ ] Handshake `ib_insync` riuscito
- [ ] Compose valido e riproducibile
- [ ] Log accessibili e monitorati
- [ ] Watchdog attivo se necessario

---

## 11) Riferimenti rapidi

### Comandi utili

```bash
# Verifica stato container
docker ps -a --filter name=gateway

# Log completi IBC
docker logs gateway-headless -f

# Restart container
docker restart gateway-headless

# Verifica connessione API
docker exec gateway-headless sh -c "netstat -an | grep 4001"

# Kill e riavvio completo
docker-compose down && docker-compose up -d
```

### File importanti

* `/opt/ibgateway/jts.ini` - Configurazione principale Gateway
* `/app/ibc/config.ini` - Configurazione IBC
* `/app/ibc/logs/ibc_output.log` - Log principale IBC
* `/app/ibkr/logs/` - Log Gateway IBKR
* `/app/logs/trusted_ips_fix.log` - Log watchdog (se abilitato)

---

## 12) Troubleshooting comune

### Gateway non si avvia

1. Verificare che Xvfb sia in esecuzione
2. Controllare le dipendenze Java e X11
3. Verificare i log in `/app/ibkr/logs/`

### Porta 4001 non in ascolto

1. Verificare che ApiOnly=true in jts.ini
2. Controllare TrustedIPs in jts.ini
3. Verificare firewall e iptables

### 2FA timeout

1. Impostare `TWOFA_TIMEOUT_ACTION=restart` se si usa automazione
2. Verificare connettività IBKR Mobile
3. Considerare TOTP come alternativa

### Watchdog non funziona

1. Verificare che lo script abbia permessi di esecuzione
2. Controllare il log in `/app/logs/trusted_ips_fix.log`
3. Verificare che `TRUSTED_CIDRS` sia impostato correttamente
