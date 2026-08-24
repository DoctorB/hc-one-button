HCOneButton 1.21.1 - CUSTOM FIXED ACTION PANEL BINDINGS

- I binding degli slot del pannello Azioni sono ora configurabili dalle opzioni.
- Default invariati: SLOT 01..09 = SHIFT+1..9, SLOT 10 = SHIFT+0, SLOT 11..18 = CTRL+SHIFT+1..8.
- La configurazione e' legata allo SLOT, non alla spell e non alla classe: il tasto dello slot resta stabile su tutti i personaggi.
- Clicca "Configura binding slot..." nelle opzioni, poi clicca un binding e premi direttamente la combinazione desiderata.
- ESC annulla la cattura; DEL/BACKSPACE rimuove il binding; "Default" ripristina il singolo slot; "Ripristina tutti" resetta l'intera griglia.
- I duplicati tra slot HCOB vengono rifiutati. Un nuovo binding puo' sostituire un binding WoW esistente e viene salvato nel binding set attuale.
- Le modifiche secure vengono applicate solo fuori combattimento.
- Layout fisso, spell per slot, Advisor Engine 2.0 e protocollo pixel v3 restano invariati.

HCOneButton 1.18.8 - MATCHED ACTION PANEL WIDTH

- BASE e Advisor ora condividono un unico contenitore visivo con lo stesso linguaggio del pannello Azioni.
- Il vecchio gap tra pulsante e Advisor e' stato ridotto e il bordo di stato (OK/CAUTION/DANGER) avvolge l'intero Core HUD.
- Il DPS meter e le barre Swing/HP/Resource sono integrati nel footer dello stesso blocco invece di sembrare pannelli separati.
- L'icona Advisor usa lo stesso trattamento/bordo delle icone Azioni.
- Il pannello Azioni 1.18.x resta invariato e viene ancorato direttamente sotto il nuovo Core HUD.
- Nessuna modifica alla rotazione, ai secure slot, ai binding o al protocollo pixel v3.

HCOneButton 1.18.6 - DETERMINISTIC ACTION SLOTS + SLOT-ONLY PIXEL PROTOCOL

- Il pannello Azioni NON compatta piu' le spell in base a livello/spell apprese.
- Ogni classe ha un ordine fisso e immutabile. Esempio Hunter: 01 Hunter's Mark, 02 Serpent Sting, 03 Arcane Shot, 04 Aimed Shot, ...
- Le spell non ancora apprese mantengono il loro slot, restano visibili ma molto scure e non eseguono nulla.
- SHIFT+1/2/3... resta quindi semanticamente legato allo stesso slot per tutta la vita del personaggio.
- Pixel protocol v3: il reader conosce SOLO colore -> slot. Non contiene nomi spell o classi.
- Console reader: SLOT 02 | SHIFT+2, non SERPENT STING.
- Quando impari una nuova spell, HCOneButton abilita il suo slot senza spostare gli altri.

HCOneButton 1.18.3 - RECTANGULAR PANEL BORDER FIX

- Corretto l'artefatto blu/verde interno ai pannelli rettangolari.
- Causa: UI-Quickslot2 (texture per action button quadrati) veniva stirata sui pannelli larghi.
- Advisor, DPS, Actions e Profession Coach ora usano bordi reali da 1 px sui quattro lati.
- UI-Quickslot2 resta solo sulle icone quadrate, dove e' appropriata.
- Tutte le funzioni della 1.18.2 restano invariate.

HCOneButton 1.18.3 Rectangular Panel Border Fix
- Secure action icons enlarged from 28px/9 columns to 44px/6 columns.
- Action panel has its own scale (default 1.0), independent from /hcob scale.
- Radial cooldown swipe on every clickable spell.
- Numeric cooldown text for real cooldowns (>1.6s); GCD does not clutter the numbers.
- Red border + R = hostile target out of range.
- Desaturated/dim icon = not currently usable (mana/rage/condition).
- Recommended action has a pulsing yellow glow.
- Tooltip reports cooldown/range/usable state.
- /hcob actions scale 0.8-1.5

HCOneButton 1.18.2 - COMPACT CLICKABLE ACTIONS + COOLDOWN UI

- Nuovo pannello AZIONI CLICCABILI sotto l Advisor: ogni icona e un SecureActionButton con spell/macro fissa configurata fuori combat.
- v1.18.2: rimosso il testo/legenda dal pannello azioni; restano solo le icone, con meno spazio verticale occupato.
- In combattimento HCOneButton NON cambia l azione protetta: cambia solo il glow sull icona consigliata.
- Cliccando direttamente l icona illuminata esegui la spell senza cercarla sulla action bar.
- Supporto per tutte le 9 classi Classic; il pannello mostra solo le spell gia apprese.
- Hunter: Feed Pet usa il cibo smart scelto fuori combat; Feign Death include pet passive + follow; Mend Pet punta al pet.
- Mage: Frost Nova cliccabile mantiene Rank 1 per il controllo efficiente.
- /hcob actions on|off abilita/disabilita il pannello (fuori combat).
- La singola icona grande dell Advisor resta solo display: Blizzard non consente di cambiarne dinamicamente la spell protetta durante il combattimento.

HCOneButton 1.17.1 HOTFIX

Hunter Auto Shot: BASE now starts Auto Shot once per target/combat using a castsequence and then leaves the auto-repeat alone. The Hunter UI says PULL / AUTO instead of BASE SPAM and, during combat, shows LASCIA CORRERE when there is no manual priority.

HCOneButton 1.17.1 - HUNTER AUTO SHOT FIX + PROFESSION COACH

PROFESSIONI
- Rileva automaticamente le professioni Classic apprese, incluse Cooking, Fishing e First Aid.
- Modulo event-driven: nessuna scansione professioni nel loop combat.
- Pannello PROF COACH visibile solo fuori combattimento; /hcob prof stampa il piano completo.
- First Aid ha percorso embedded 1-300 con bandage corretto per fascia, cloth in borsa, trainer/book/Triage gate.
- Crafting professions: quando la finestra e' aperta, valuta ricette conosciute, colore skill-up, reagenti e disponibilita'; preferisce Orange > Yellow > Green, mai Grey.
- Suggerisce piccoli batch e rivaluta per evitare di continuare a craftare una ricetta quando cambia colore.
- Se mancano materiali mostra il primo collo di bottiglia invece di consigliare craft impossibili.
- Supporta anche l'interfaccia Craft Classic (Enchanting).
- Herbalism/Mining/Skinning hanno fasce 1-300 con nodi/mob e zone consigliate.
- Fishing usa una soglia comfort legata al livello per ridurre 'fish got away' e coordina zone utili con Cooking.
- Il coach non compra, crafta o raccoglie automaticamente: decide la prossima azione, l'input rimane al giocatore.
- Comandi: /hcob prof | /hcob prof on | /hcob prof off | /hcob prof refresh

HCOneButton 1.16.0 - SMART PET FEEDING

HUNTER PET FOOD
- Legge la felicita' Classic del pet: Unhappy=75% danno, Content=100%, Happy=125%.
- Fuori combat, se il pet non e' Happy, l'Advisor suggerisce NUTRI PET / PET AFFAMATO.
- ALT+CTRL e' contestuale: in combat = Mend Pet; fuori combat = Feed Pet + cibo scelto.
- Se il pet e' gia' Happy, ALT+CTRL non spreca cibo fuori combat.
- Se Feed Pet Effect e' gia' attivo, il feed viene disarmato finche' l'effetto non termina.
- La dieta viene letta direttamente dal pet (Meat/Fish/Bread/Cheese/Fruit/Fungus).
- Database embedded di 199 cibi Classic; nessuna dipendenza runtime da altri addon.
- Scelta smart: prima fascia di livello utile, poi conjured/basic, poi cooked/buff, infine raw/cooking mats.
- Salta quest item, slot bloccati e cibo troppo basso per essere una scelta sensata.
- /hcob petfood mostra happiness, damage modifier, loyalty, dieta e cibo attualmente scelto.
- Il feed resta assistito: HCOneButton sceglie e prepara il cibo, ma lo consuma solo quando premi ALT+CTRL.

HCOneButton 1.15.0 - HUNTER HARDCORE SMART ROTATION

HUNTER
- BASE resta PET ATTACK + !AUTO SHOT: Auto Shot e' il metronomo e non viene interrotto da spam di spell costose.
- Advisor usa una finestra dopo ogni Auto Shot per Aimed/Multi/Arcane, riducendo il clipping.
- Hunter's Mark e Serpent Sting vengono saltati sui mob troppo triviali o troppo bassi di HP; Sting non viene applicato tardi.
- Arcane Shot e' burst/finisher, non mana dump permanente; con mana basso si torna naturalmente ad Auto Shot.
- CTRL = Multi-Shot; ALT+SHIFT = Aimed Shot (o Arcane Shot prima di Aimed); CTRL+SHIFT = Scatter Shot con fallback Concussive Shot.
- ALT = Wing Clip; ALT+CTRL = Mend Pet; ALL MODS = pet passive + pet follow + Feign Death.
- Pet smart: Mend Pet prioritario quando il pet sta crollando, ma non mentre il mob e' gia' addosso al player.
- Dead-zone smart: Wing Clip -> distanza -> riprendi Auto Shot; Scatter/Concussive come peel quando perdi aggro dal pet.
- BM: Bestial Wrath/Intimidation solo su fight abbastanza lunghi; Rapid Fire su target resistenti, non sui mob gia' quasi morti.
- Multi-pull Hunter dedicato: 2 mob usa controllo/pet/Multi solo se stabile; 3+ mob passa a Feign/reset e fuga.
- Telemetria aggiunge ranged speed, ranged min/max e ranged AP per ottimizzare i log Hunter nelle build successive.

HCOneButton 1.14.1 - BUTTON4 / secure click fix

- Secure button registered for AnyDown + AnyUp.
- useOnKeyDown follows ActionButtonUseKeyDown.
- /hcob bindtest [KEY] diagnoses the active binding.

HC One Button 1.14.0 - MAGE HARDCORE SMART ROTATION
=====================================================
MAGE
- BASE per spec: Frost = Frostbolt; Fire = Fireball; Arcane = Fireball fino al late leveling, poi Frostbolt. Arcane Missiles non e' piu' lo spam base Arcane.
- SHIFT con target ostile = wand; senza target ostile = Arcane Intellect.
- CTRL = Frost Nova Rank 1 per controllo a costo minimo.
- ALT = Blink; CTRL+SHIFT = Counterspell; ALT+SHIFT = Fire Blast; ALT+CTRL = Polymorph.
- ALL MODS = panic chain: Ice Block -> Frost Nova R1 -> Mana Shield, in base a cosa e' disponibile.
- Advisor single target: Fire Blast solo come finisher/pressione melee, Nova preventiva prima che gli HP diventino critici, Blink se Nova non e' pronta, wand finish per mana efficiency.
- Evocation viene consigliata fuori combat sotto il 40% mana.
- Ice Barrier, quando conosciuta, viene mantenuta pre-pull e riapplicata in combat se manca e il fight e ancora lungo; Cold Snap entra nel panic Advisor se Nova/Block non sono disponibili.
- Armor smart: Frost usa Ice/Frost Armor per sicurezza; Fire/Arcane preferiscono Mage Armor quando disponibile.
- Fire: Pyroblast opener solo su elite/rare o target sopra livello, non su ogni mob.
- Multi-pull Mage dedicato: 3+ mob = Nova/Blink/panic; 2 mob = Nova se vicini, Polymorph se hai spazio, warning mana se il pull si prolunga.
- Mana Shield non fa parte della rotazione normale: viene tenuto come buffer di emergenza per non bruciare la risorsa principale del Mage.

HC One Button 1.12.0
====================
Warrior adaptive rage tuning from v1.11 telemetry:
- BASE remains safe: Heroic Strike is still NEVER spammed automatically.
- Below level 20, very trivial mobs (3+ levels lower) use an Advisor HS threshold 5 rage below the configured value (35 -> 30 by default).
- Mobs 2 levels lower keep the configured reserve; near-level/harder mobs keep at least 35 rage.
- At level 20+, execute-phase HS threshold can still drop by 5, never below 25.
- Hamstring CAUTION/DANGER recommendations no longer repeat while your Hamstring debuff is already active.
- Goal: move low-level rage from the 40-55 range toward a useful reserve without returning to v1.10 rage starvation.

HC One Button 1.11.0
====================
Warrior DPS/rage fix:
- BASE SPAM no longer queues Heroic Strike.
- Heroic Strike is suggested manually by the Advisor (ALT+SHIFT) only above the configured rage threshold.
- Below level 20 the threshold is never reduced below 35 rage; trivial mobs (2+ levels below) require at least 45 rage.
- Existing SavedVariables with Heroic Strike spam enabled are migrated automatically to the safe behavior.

HC One Button v1.10.0 - HARDCORE DANGER ADVISOR
===================================================

HC DANGER / CAUTION
- DANGER e CAUTION ora hanno precedenza grafica sul tipo di input: un Hamstring su ALT resta rosso/arancio e non appare piu come normale HCOB blu.
- 2 mob: CAUTION anticipato con Thunder Clap, Demoralizing Shout o preparazione fuga. Se gli HP scendono, passa a DANGER.
- 3+ mob: DANGER immediato; Warrior privilegia Retaliation se pronta, poi Thunder Clap / Demo Shout / fuga.
- Interrupt interrompibili mantengono priorita sui warning CAUTION, salvo HP gia critici.
- Fight trend single-target ha due livelli: CAUTION quando il rapporto TTD/TTK peggiora, DANGER quando la gara diventa realmente sfavorevole.
- Nuova opzione: HC danger advisor.

UI
- Background, bordo e DPS meter diventano arancio in CAUTION e rossi in DANGER.
- I tasti restano espliciti: ALT/CTRL + bind HCOB oppure PREMI DALLA BARRA.

TELEMETRY v7
- Salva percentuale del fight in DANGER/CAUTION, percentuale di consigli manuali e numero di transizioni di rischio.
- /hcob log last mostra i nuovi dati; /hcob log stats mostra la media rischio degli ultimi fight v7.

HC One Button v1.9.0 - COMPACT HUD + SMART HC ADVISOR + MINI DPS
=================================================================

UI v1.9
- Advisor compatto: icona + badge MANUALE/HCOB/BASE/DANGER/OK + nome abilita + input + motivo.
- Advisor e mini DPS meter seguono la stessa scala del pulsante BASE. Risolve la sproporzione vista con scale come 0.7.
- Rimossi i vecchi testi sotto il pulsante che si sovrapponevano alle barre.
- Swing/HP/resource bars ora sono subito sotto il pulsante.
- Mini DPS meter sotto l Advisor: DPS live, AVG ultimi 5 fight della build corrente, danno e durata.
- /hcob dps on|off oppure checkbox nelle opzioni.

SMART HC ADVISOR
- Execute/Overpower rimangono le finestre offensive piu importanti.
- Battle Shout in combat viene consigliato solo quando il target e ancora abbastanza sano e hai rage sufficiente.
- Bloodrage e piu prudente: HP >=85%, rage bassa, single target e prima parte del fight.
- Rend manuale viene evitato sui mob triviali.
- Nuovo fight trend: su single target, dopo alcuni secondi stima time-to-kill del mob e pressione subita. Se stai perdendo la gara passa a FIGHT PEGGIORA e suggerisce fuga/controllo.

TELEMETRY v6
- Conserva le metriche v5 e aggiunge i dati necessari al fight trend.
- Corretto anche il nome sessione automatico quando cambia versione, senza sovrascrivere sessioni personalizzate.

HC One Button v1.8.1 - SMART PRIORITY / RANK-SAFE
======================================================

WARRIOR EARLY LEVELING
- Fix critico: rilevamento spell rank-safe. Un rank superiore di Heroic Strike non viene piu scambiato per spell sconosciuta.
- BASE SPAM: /startattack + Charge fuori combat; Heroic Strike non e mai incluso nel BASE e viene suggerito dall Advisor su ALT+SHIFT quando la rage e sufficiente.
- Rend intelligente: fuori combat, sul target selezionato, prepara Rend x1 solo se pari/quasi pari livello o elite; lo salta sui mob triviali.
- Advisor: Execute/Overpower/buff/AoE/panic restano situazionali. A rage alta, se HS non risulta queued, mostra PREMI BASE.
- Il secure macro viene ricostruito su PLAYER_TARGET_CHANGED solo fuori combat, quindi resta compatibile col combat lockdown.

TELEMETRY v5
- baseClicks per fight.
- heroicQueuedPct: percentuale dei campioni in cui Heroic Strike risulta in coda.
- Mantiene rage high/cap e metriche precedenti.

DIAGNOSTICA
- /hcob status mostra heroicKnown e autoRend.
- /hcob plan stampa la macro effettiva generata.
- /hcob rendspam on|off controlla il Rend pre-pull intelligente.

HC One Button v1.6.0 - ADAPTIVE ROTATION + TELEMETRY FIX
===========================================================

WARRIOR
- L1-21: spam base = auto attack + Charge; nessun rage spender automatico.
- L22-35: opzionale 1 Sunder per target nello spam base, mai 3.
- Mortal Strike/Bloodthirst: spam torna auto+Charge; spender gestiti dall Advisor.
- Advisor: Execute > Overpower > spender principali > AoE > Battle Shout > Rend > Sunder situazionale > Bloodrage > Heroic Strike.
- Heroic Strike ha soglia adattiva conservativa: sotto il 20 non scende sotto 35 rage; sui mob triviali (2+ livelli sotto) richiede almeno 45 rage.

TELEMETRY v3
- Nemici rilevati dai GUID che scambiano realmente danno/miss con player/pet.
- Supporta correttamente mob neutrali/gialli, senza dipendere dal reaction flag HOSTILE.
- Kills deduplicate: PARTY_KILL + UNIT_DIED non contano piu due volte lo stesso GUID.
- Schema fight aggiornato a 3; storico precedente viene conservato.

HC One Button v1.5.1 - HYBRID BALANCED

Novita v1.4:
- Warrior early leveling: spam base = auto attack + Charge + fino a 3 Sunder Armor per target.
- Sunder base si disattiva automaticamente quando impari Mortal Strike o Bloodthirst.
- Advisor non mostra piu il punto interrogativo quando non c'e una priorita: mostra BASE OK + icona base.
- /hcob sunder on|off e opzione grafica dedicata Warrior.
- Proc/cooldown/situazionali restano manuali: Overpower, Execute, Rend, Bloodrage, Thunder Clap, Heroic Strike, ecc.

HC One Button v1.3.0 - HYBRID ADVISOR
=====================================

FILOSOFIA
- Il tasto BASE esegue solo azioni sicure da spammare.
- Il pannello ADVISOR a destra suggerisce la spell situazionale da castare manualmente.
- Proc, execute, DoT, spender, AoE, interrupt e panic non vengono piu inseriti alla cieca nello spam.
- Il motore resta adattivo a classe, livello, talenti e spellbook.

WARRIOR
- BASE: /startattack + Charge fuori combattimento.
- ADVISOR: Execute, Overpower, Mortal Strike/Bloodthirst, Whirlwind/Thunder Clap multi-target, Rend, Bloodrage e Heroic Strike in base a rage.
- Heroic Strike default: consigliato da 35 rage; regolabile dalle opzioni.

UI
- Pulsante sinistro = BASE SPAM.
- Pannello destro = spell consigliata manualmente + motivo.
- /hcob options apre le opzioni.

DIAGNOSTICA
/hcob status
/hcob errors
/hcob reseterrors
/hcob plan

INSTALLAZIONE
Chiudi WoW e sostituisci completamente la cartella HCOneButton in:
World of Warcraft/_classic_era_/Interface/AddOns/HCOneButton/

Bind e SavedVariables restano invariati.


COMBAT TELEMETRY v1.5
---------------------
/hcob log last      riepilogo ultimo combattimento
/hcob log stats     medie ultimi 10 fight
/hcob log on|off    abilita/disabilita logger
/hcob log max 60    quanti fight conservare (10-200)
/hcob log session X etichetta la sessione di test
/hcob log export    istruzioni per il file SavedVariables
/hcob log clear     cancella lo storico

I dati sono nella tabella HCOB_CombatLog del file:
WTF/Account/<account>/SavedVariables/HCOneButton.lua
Il client scrive il file durante /reload, logout o uscita dal gioco.


v1.5.1: fixed CombatTelemetry local function scope bug (CombatLogFlagIsHostile).


v1.7.0: Warrior early-level BASE SPAM queues Heroic Strike to prevent rage capping; major spenders remain manual via Advisor. Telemetry schema 4 adds rage >=80% and cap time.


v1.8.1 UI: Advisor now clearly distinguishes manual casts, HCOB modifier actions, base spam, danger and idle states.

v1.13.0
- Warrior Rend dinamico: Rend x1 anche sui mob fino a 4 livelli sotto se il fight e' ancora all'inizio.
- Heroic Strike finisher: sotto 30% HP scarica piu' aggressivamente la rage se Execute non e' conosciuto.
- Telemetria gear: main/off-hand itemID, AP, danno arma e speed registrati a inizio fight per diagnosticare il limite DPS.

Pixel diagnostico RGB v2 (v1.18.4)
-----------------------------------
Il pixel diagnostico e' passivo e serve solo a strumenti esterni di lettura.
Un singolo RGB codifica classe, slot visibile del pannello Azioni e indice logico dell'azione:
  R = slot visibile * 12
  G = codice classe * 24
  B = indice azione * 12
Nero = nessuna azione consigliata. Bianco = azione Advisor non mappata nel pannello.
Compatibile con HCOneButtonPixelReader_v2.py / .exe.


=== v1.18.5 - Action slot keybinds ===
The clickable Advisor panel is automatically bound by visible SLOT (not by spell):
  Slot 1-9   : SHIFT+1 ... SHIFT+9
  Slot 10    : SHIFT+0
  Slot 11-18 : CTRL+SHIFT+1 ... CTRL+SHIFT+8
Use /hcob actions binds to print the current slot -> key -> spell map.
Use /hcob actions bind off to stop future automatic rebinding.



=== v1.20.0 ADVISOR ENGINE 2.0 - MAGE + WARRIOR ===
- Advisor Engine 2.0 esteso a Mage e Warrior: non vince piu' il primo if valido; tutte le azioni diventano candidati con score.
- Warrior Survival Reserve specifico: HP, rage, Shield Wall, Retaliation, Hamstring, Thunder Clap e Demo Shout.
- Warrior: Execute/Overpower/core strike, Rend, Sunder, Battle Shout, Bloodrage e Heroic Strike competono tramite score + TTK + reserve.
- Heroic Strike aumenta la soglia quando la survival reserve e' bassa e la abbassa quando il fight e' sicuro/in chiusura.
- Warrior: Shield Wall entra anche nel panic reale quando disponibile.
- Mage Survival Reserve piu' completo: HP, mana, Blink, Nova, Ice Block, Cold Snap, Barrier e Mana Shield.
- Mage: Nova/Blink/Cold Snap/Barrier/Mana Shield/Wand/Fire Blast/Pyro sono ora candidati scored con TTK/reserve e hysteresis.
- Cone of Cold puo' fare da bridge di controllo quando Nova e' in cooldown e il target e' in melee.
- UI, layout 1.18.8, slot fissi, binding e protocollo Pixel Reader restano invariati.

=== v1.19.0 ADVISOR ENGINE 2.0 ===
- Hunter recommendations are now scored candidates instead of first-match wins.
- Rolling 5s TTK/TTD with confidence replaces whole-fight trend averages.
- Survival Reserve combines HP, mana, pet state, escape cooldowns and enemy count.
- Short hysteresis/stability window reduces recommendation flicker.
- DoTs/Mark/burst use predicted remaining fight duration when confidence is sufficient.
- Combat telemetry schema 10 records average/minimum Survival Reserve.
- /hcob advisor debug prints reserve, rolling dynamics and top scored candidates.


=== v1.21.0 ADVISOR ENGINE 2.0 - CLASS COVERAGE ===
- Warlock, Priest, Rogue, Paladin e Shaman portati su Advisor Engine 2.0 con candidati scored, rolling TTK/TTD, hysteresis e Survival Reserve specifica.
- Druid resta volutamente sulla logica base.
- Warlock: Life Tap subordinato a HP/reserve/TTD, DoT basati su TTK, Drain Life/Death Coil/Fear survival, wand/shard efficiency.
- Priest: Shield/Weakened Soul, heal dinamico, SW:P/Mind Blast/Mind Flay scoring e wand-first efficiency.
- Rogue: energy/combo-point logic, Eviscerate vs Slice and Dice, Evasion/Gouge/Kidney/Vanish safety, opener Stealth/Garrote/Cheap Shot.
- Paladin: seal in base a weapon speed, Judgement mana-aware, heal/bubble/stun survival, Exorcism solo Undead/Demon e Hammer of Wrath finisher.
- Shaman: shock mana discipline, Flame Shock TTK-aware, Stoneclaw/Earthbind/Frost Shock kiting, Healing Wave survival e totem presence checks.
- Multi-pull e FIGHT SFAVOREVOLE ora hanno risposte specifiche per queste cinque classi.
- Slot gia' esistenti non cambiano. Le nuove spell sono state aggiunte solo in coda agli slot liberi, mantenendo deterministico il protocollo slot-only del Pixel Reader.
