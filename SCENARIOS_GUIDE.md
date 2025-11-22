# Grid-Forming Converter Simulation Scenarios Guide
# Guide des Scénarios de Simulation pour Convertisseur Grid-Forming

---

## Table of Contents / Table des Matières

### English
- [Introduction](#introduction-english)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [All Simulation Scenarios](#all-simulation-scenarios)
- [Parametric Studies](#parametric-studies)
- [Automated Testing](#automated-testing)
- [Configuration Parameters](#configuration-parameters)
- [Troubleshooting](#troubleshooting)

### Français
- [Introduction](#introduction-français)
- [Prérequis](#prérequis)
- [Démarrage Rapide](#démarrage-rapide)
- [Tous les Scénarios de Simulation](#tous-les-scénarios-de-simulation)
- [Études Paramétriques](#études-paramétriques)
- [Tests Automatisés](#tests-automatisés)
- [Paramètres de Configuration](#paramètres-de-configuration)
- [Dépannage](#dépannage)

---

## Introduction (English)

This guide provides comprehensive instructions for running all simulation scenarios of the Grid-Forming (GFM) Converter model in MATLAB/Simulink/Simscape. The GFM converter emulates the behavior of traditional synchronous generators, providing essential grid services including:

- **Inertia Emulation**: Virtual Synchronous Machine (VSM) with configurable inertia constant
- **Damping**: Frequency-dependent damping power for grid stabilization
- **Voltage & Frequency Support**: Autonomous voltage and frequency regulation
- **Fault Current Contribution**: Provides fault current during grid disturbances
- **Black-Start Capability**: Can operate in islanded mode without grid connection
- **Grid Code Compliance**: Tested against GC0137 (UK) frequency ride-through requirements

---

## Introduction (Français)

Ce guide fournit des instructions complètes pour exécuter tous les scénarios de simulation du modèle de convertisseur Grid-Forming (GFM) dans MATLAB/Simulink/Simscape. Le convertisseur GFM émule le comportement des générateurs synchrones traditionnels, fournissant des services essentiels au réseau, notamment :

- **Émulation d'Inertie**: Machine Synchrone Virtuelle (VSM) avec constante d'inertie configurable
- **Amortissement**: Puissance d'amortissement dépendant de la fréquence pour la stabilisation du réseau
- **Support de Tension et Fréquence**: Régulation autonome de la tension et de la fréquence
- **Contribution au Courant de Défaut**: Fournit du courant de défaut pendant les perturbations du réseau
- **Capacité de Démarrage Autonome**: Peut fonctionner en mode îloté sans connexion au réseau
- **Conformité aux Codes de Réseau**: Testé selon les exigences de tenue en fréquence GC0137 (UK)

---

## Prerequisites

### Software Requirements / Exigences Logicielles

**English:**
- MATLAB R2023a or later (R2023b recommended)
- Simulink
- Simscape
- Simscape Electrical
- MATLAB Test Framework (for automated tests)

**Français:**
- MATLAB R2023a ou ultérieur (R2023b recommandé)
- Simulink
- Simscape
- Simscape Electrical
- Framework de Test MATLAB (pour les tests automatisés)

### Hardware Requirements / Exigences Matérielles

**English:**
- Minimum 8 GB RAM (16 GB recommended)
- Multi-core processor recommended for faster simulations

**Français:**
- Minimum 8 Go de RAM (16 Go recommandé)
- Processeur multi-cœurs recommandé pour des simulations plus rapides

---

## Quick Start

### English

1. **Clone and Open Project**
   ```matlab
   % Navigate to repository directory
   cd('/path/to/Zaid_Power-Converter-Circuit-Control-Simscape')

   % Open MATLAB project
   openProject('PowerConverterCircuitAndControlDesignWithSimscape.prj')
   ```

2. **Load Input Parameters**
   ```matlab
   % Run the input parameters live script
   run('Script_Data/GridFormingConverterInputParameters.mlx')
   ```

3. **Run a Single Scenario**
   ```matlab
   % Configure test condition
   testCondition.activePowerMethod = 'Virtual Synchronous Machine';
   testCondition.currentLimitMethod = 'Virtual Impedance';
   testCondition.SCR = 2.5;  % Short Circuit Ratio
   testCondition.XbyR = 5;   % X/R ratio
   testCondition.testCondition = 'Normal operation';

   % Run simulation with plots
   outputTable = PlotGridFormingConverter(testCondition, 1);
   ```

4. **Run All Scenarios**
   ```matlab
   % Configure test condition
   testCondition.activePowerMethod = 'Virtual Synchronous Machine';
   testCondition.currentLimitMethod = 'Virtual Impedance';
   testCondition.SCR = 2.5;
   testCondition.XbyR = 5;

   % Run all scenarios
   outputTable = PlotGridFormingConverter(testCondition, 1, 'All');
   ```

---

### Français

### Démarrage Rapide

1. **Cloner et Ouvrir le Projet**
   ```matlab
   % Naviguer vers le répertoire du dépôt
   cd('/chemin/vers/Zaid_Power-Converter-Circuit-Control-Simscape')

   % Ouvrir le projet MATLAB
   openProject('PowerConverterCircuitAndControlDesignWithSimscape.prj')
   ```

2. **Charger les Paramètres d'Entrée**
   ```matlab
   % Exécuter le script live des paramètres d'entrée
   run('Script_Data/GridFormingConverterInputParameters.mlx')
   ```

3. **Exécuter un Scénario Simple**
   ```matlab
   % Configurer la condition de test
   testCondition.activePowerMethod = 'Virtual Synchronous Machine';
   testCondition.currentLimitMethod = 'Virtual Impedance';
   testCondition.SCR = 2.5;  % Ratio de Court-Circuit
   testCondition.XbyR = 5;   % Ratio X/R
   testCondition.testCondition = 'Normal operation';

   % Exécuter la simulation avec graphiques
   outputTable = PlotGridFormingConverter(testCondition, 1);
   ```

4. **Exécuter Tous les Scénarios**
   ```matlab
   % Configurer la condition de test
   testCondition.activePowerMethod = 'Virtual Synchronous Machine';
   testCondition.currentLimitMethod = 'Virtual Impedance';
   testCondition.SCR = 2.5;
   testCondition.XbyR = 5;

   % Exécuter tous les scénarios
   outputTable = PlotGridFormingConverter(testCondition, 1, 'All');
   ```

---

## All Simulation Scenarios

## Tous les Scénarios de Simulation

---

### Scenario 1: Normal Operation / Opération Normale

#### English

**Description:** Baseline steady-state operation to verify stable GFM converter behavior.

**How to Run:**
```matlab
% Configure
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Normal operation';

% Execute
outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Active Power Reference: 0.7 pu
- Reactive Power Reference: 0.3 pu
- Grid Frequency: 50 Hz
- Grid Voltage: 1.0 pu
- Simulation Time: ~5 seconds

**Expected Results:**
- Stable voltage waveform (±1% variation)
- Stable frequency (50 Hz ±0.02 Hz)
- Active power: 0.7 pu ±0.01
- Reactive power: 0.3 pu ±0.01
- Test outcome: "Stable"

**Output Plots:**
- GFM Output Active Power (pu vs time)
- GFM Output Reactive Power (pu vs time)
- GFM Output Voltage (3-phase waveforms)
- GFM Output Current (3-phase waveforms)

---

#### Français

**Description:** Opération en régime permanent de base pour vérifier le comportement stable du convertisseur GFM.

**Comment Exécuter:**
```matlab
% Configurer
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Normal operation';

% Exécuter
outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Référence de Puissance Active: 0.7 pu
- Référence de Puissance Réactive: 0.3 pu
- Fréquence du Réseau: 50 Hz
- Tension du Réseau: 1.0 pu
- Temps de Simulation: ~5 secondes

**Résultats Attendus:**
- Forme d'onde de tension stable (variation ±1%)
- Fréquence stable (50 Hz ±0.02 Hz)
- Puissance active: 0.7 pu ±0.01
- Puissance réactive: 0.3 pu ±0.01
- Résultat du test: "Stable"

**Graphiques de Sortie:**
- Puissance Active de Sortie GFM (pu vs temps)
- Puissance Réactive de Sortie GFM (pu vs temps)
- Tension de Sortie GFM (formes d'onde triphasées)
- Courant de Sortie GFM (formes d'onde triphasées)

---

### Scenario 2: Active Power Reference Change / Changement de Référence de Puissance Active

#### English

**Description:** Step change in active power reference to test power tracking capability.

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in active power reference';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Initial Pref: 0.7 pu
- Final Pref: 0.9 pu
- Change Time: 3 seconds (disturbanceTime)
- Step Type: Step change
- Simulation Time: ~8 seconds

**Expected Results:**
- Power tracks reference within 0.5s settling time
- Overshoot < 10%
- Minimal impact on frequency (< 0.1 Hz deviation)
- Minimal impact on reactive power (< 0.05 pu change)
- Test outcome: "Stable"

**Output Plots:**
- Pref vs Pmeas comparison
- Reactive Power (Qmeas)
- Voltage waveforms during transient
- Current waveforms during transient

---

#### Français

**Description:** Changement en échelon de la référence de puissance active pour tester la capacité de suivi de puissance.

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in active power reference';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Pref Initial: 0.7 pu
- Pref Final: 0.9 pu
- Temps de Changement: 3 secondes (disturbanceTime)
- Type de Step: Changement en échelon
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- La puissance suit la référence en moins de 0.5s
- Dépassement < 10%
- Impact minimal sur la fréquence (< 0.1 Hz de déviation)
- Impact minimal sur la puissance réactive (< 0.05 pu de changement)
- Résultat du test: "Stable"

**Graphiques de Sortie:**
- Comparaison Pref vs Pmeas
- Puissance Réactive (Qmeas)
- Formes d'onde de tension pendant le transitoire
- Formes d'onde de courant pendant le transitoire

---

### Scenario 3: Reactive Power Reference Change / Changement de Référence de Puissance Réactive

#### English

**Description:** Step change in reactive power reference to test voltage control capability.

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in reactive power reference';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Initial Qref: 0.3 pu
- Final Qref: 0.6 pu
- Change Time: 3 seconds
- Step Type: Step change
- Simulation Time: ~8 seconds

**Expected Results:**
- Reactive power tracks reference within 0.5s
- Voltage magnitude adjusts accordingly
- Minimal coupling with active power
- Test outcome: "Stable"

---

#### Français

**Description:** Changement en échelon de la référence de puissance réactive pour tester la capacité de contrôle de tension.

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in reactive power reference';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Qref Initial: 0.3 pu
- Qref Final: 0.6 pu
- Temps de Changement: 3 secondes
- Type de Step: Changement en échelon
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- La puissance réactive suit la référence en moins de 0.5s
- L'amplitude de tension s'ajuste en conséquence
- Couplage minimal avec la puissance active
- Résultat du test: "Stable"

---

### Scenario 4: Grid Voltage Change / Changement de Tension du Réseau

#### English

**Description:** Grid internal voltage magnitude variation to test voltage regulation.

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid voltage';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Initial Grid Voltage: 1.0 pu
- Final Grid Voltage: 0.9 pu (typical)
- Change Time: 3 seconds
- Simulation Time: ~8 seconds

**Expected Results:**
- GFM compensates to maintain output voltage
- Reactive power adjusts automatically
- Active power remains relatively constant
- Test outcome: "Stable"

---

#### Français

**Description:** Variation de l'amplitude de la tension interne du réseau pour tester la régulation de tension.

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid voltage';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Tension Réseau Initiale: 1.0 pu
- Tension Réseau Finale: 0.9 pu (typique)
- Temps de Changement: 3 secondes
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- Le GFM compense pour maintenir la tension de sortie
- La puissance réactive s'ajuste automatiquement
- La puissance active reste relativement constante
- Résultat du test: "Stable"

---

### Scenario 5: Local Load Change / Changement de Charge Locale

#### English

**Description:** Step change in local load connected at point of common coupling (PCC).

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in local load';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Initial Load: Pload = 0.3 pu, Qload = 0.1 pu
- Final Load: Pload = 0.5 pu, Qload = 0.2 pu
- Change Time: 3 seconds
- Simulation Time: ~8 seconds

**Expected Results:**
- GFM increases power output to meet load demand
- Grid shares the load with GFM
- Voltage and frequency remain stable
- Test outcome: "Stable"

**Output Plots:**
- Local Load P & Q (reference vs measured)
- GFM Output Active & Reactive Power
- Voltage and current waveforms

---

#### Français

**Description:** Changement en échelon de la charge locale connectée au point de couplage commun (PCC).

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in local load';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Charge Initiale: Pload = 0.3 pu, Qload = 0.1 pu
- Charge Finale: Pload = 0.5 pu, Qload = 0.2 pu
- Temps de Changement: 3 secondes
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- Le GFM augmente la puissance de sortie pour répondre à la demande de charge
- Le réseau partage la charge avec le GFM
- La tension et la fréquence restent stables
- Résultat du test: "Stable"

**Graphiques de Sortie:**
- Charge Locale P & Q (référence vs mesuré)
- Puissance Active & Réactive de Sortie GFM
- Formes d'onde de tension et courant

---

### Scenario 6: Small Frequency Change (1 Hz/s, +0.5 Hz) / Petit Changement de Fréquence

#### English

**Description:** Gradual grid frequency increase to test frequency tracking and inertial response.

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid frequency 1Hz/s, +0.5Hz';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Initial Frequency: 50 Hz
- Final Frequency: 50.5 Hz
- Rate of Change: 1 Hz/s (df/dt)
- Duration: 0.5 seconds
- Total Simulation Time: ~8 seconds

**Expected Results:**
- GFM tracks grid frequency smoothly
- For VSM: Damping power (Pdamping) responds to df/dt
- For Droop: Power adjusts per droop characteristic
- No loss of synchronization
- Test outcome: "Stable"

**Output Plots:**
- Grid Frequency vs GFM Frequency
- Damping Power (VSM only)
- GFM Active & Reactive Power
- Voltage and current waveforms

---

#### Français

**Description:** Augmentation progressive de la fréquence du réseau pour tester le suivi de fréquence et la réponse inertielle.

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid frequency 1Hz/s, +0.5Hz';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Fréquence Initiale: 50 Hz
- Fréquence Finale: 50.5 Hz
- Taux de Changement: 1 Hz/s (df/dt)
- Durée: 0.5 secondes
- Temps Total de Simulation: ~8 secondes

**Résultats Attendus:**
- Le GFM suit la fréquence du réseau en douceur
- Pour VSM: Puissance d'amortissement (Pdamping) répond à df/dt
- Pour Droop: La puissance s'ajuste selon la caractéristique de droop
- Pas de perte de synchronisation
- Résultat du test: "Stable"

**Graphiques de Sortie:**
- Fréquence Réseau vs Fréquence GFM
- Puissance d'Amortissement (VSM uniquement)
- Puissance Active & Réactive GFM
- Formes d'onde de tension et courant

---

### Scenario 7: Large Frequency Change (2 Hz/s, +2 Hz) / Grand Changement de Fréquence

#### English

**Description:** Rapid grid frequency increase to test robustness under severe frequency transients.

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid frequency 2Hz/s, +2Hz';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Initial Frequency: 50 Hz
- Final Frequency: 52 Hz
- Rate of Change: 2 Hz/s (high df/dt)
- Duration: 1 second
- Total Simulation Time: ~8 seconds

**Expected Results:**
- GFM maintains synchronism despite rapid change
- Higher damping power for VSM (proportional to df/dt)
- Larger power transient
- No instability or protection tripping
- Test outcome: "Stable"

---

#### Français

**Description:** Augmentation rapide de la fréquence du réseau pour tester la robustesse sous des transitoires de fréquence sévères.

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid frequency 2Hz/s, +2Hz';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Fréquence Initiale: 50 Hz
- Fréquence Finale: 52 Hz
- Taux de Changement: 2 Hz/s (df/dt élevé)
- Durée: 1 seconde
- Temps Total de Simulation: ~8 secondes

**Résultats Attendus:**
- Le GFM maintient le synchronisme malgré le changement rapide
- Puissance d'amortissement plus élevée pour VSM (proportionnelle à df/dt)
- Transitoire de puissance plus importante
- Pas d'instabilité ou de déclenchement de protection
- Résultat du test: "Stable"

---

### Scenario 8: Full Range Frequency Change (GC0137 Compliance) / Changement de Fréquence sur Toute la Plage (Conformité GC0137)

#### English

**Description:** Complete frequency excursion test per UK GC0137 grid code requirements (47-52 Hz).

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid frequency 2Hz/s, +2Hz and 1Hz/s till -5Hz';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- **Phase 1**: 50 Hz → 52 Hz at 2 Hz/s (1 second)
- **Hold**: 52 Hz for ~5 seconds
- **Phase 2**: 52 Hz → 47 Hz at 1 Hz/s (5 seconds)
- **Hold**: 47 Hz for remainder
- Total Simulation Time: ~20 seconds

**Expected Results:**
- GFM operates continuously through entire 47-52 Hz range
- No disconnection or instability
- Meets GC0137 frequency ride-through requirements
- Inertial response demonstrated during df/dt
- Damping power visible in VSM mode
- Test outcome: "Stable"

**Grid Code Reference:** UK GC0137 - Frequency ride-through capability

**Output Plots:**
- Grid Frequency vs GFM Frequency (full range)
- Damping Power (shows inertial response)
- GFM Active Power (adjusts per droop/VSM)
- GFM Reactive Power
- Voltage and current waveforms

**Real-World Significance:** This test validates the GFM converter's ability to remain connected and support the grid during extreme frequency excursions, essential for high-DG penetration scenarios.

---

#### Français

**Description:** Test d'excursion de fréquence complète selon les exigences du code de réseau UK GC0137 (47-52 Hz).

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid frequency 2Hz/s, +2Hz and 1Hz/s till -5Hz';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- **Phase 1**: 50 Hz → 52 Hz à 2 Hz/s (1 seconde)
- **Maintien**: 52 Hz pendant ~5 secondes
- **Phase 2**: 52 Hz → 47 Hz à 1 Hz/s (5 secondes)
- **Maintien**: 47 Hz pour le reste
- Temps Total de Simulation: ~20 secondes

**Résultats Attendus:**
- Le GFM fonctionne en continu sur toute la plage 47-52 Hz
- Pas de déconnexion ou d'instabilité
- Conforme aux exigences de tenue en fréquence GC0137
- Réponse inertielle démontrée pendant df/dt
- Puissance d'amortissement visible en mode VSM
- Résultat du test: "Stable"

**Référence Code de Réseau:** UK GC0137 - Capacité de tenue en fréquence

**Graphiques de Sortie:**
- Fréquence Réseau vs Fréquence GFM (plage complète)
- Puissance d'Amortissement (montre la réponse inertielle)
- Puissance Active GFM (s'ajuste selon droop/VSM)
- Puissance Réactive GFM
- Formes d'onde de tension et courant

**Signification Réelle:** Ce test valide la capacité du convertisseur GFM à rester connecté et à soutenir le réseau pendant des excursions de fréquence extrêmes, essentiel pour les scénarios de forte pénétration de production décentralisée.

---

### Scenario 9: Grid Phase Jump (10 degrees) / Saut de Phase du Réseau (10 degrés)

#### English

**Description:** Sudden 10-degree phase angle jump in grid voltage to test transient stability.

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid phase by 10 degrees';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Initial Phase Angle: 0 degrees
- Final Phase Angle: 10 degrees
- Jump Type: Instantaneous (step)
- Jump Time: 3 seconds
- Simulation Time: ~8 seconds

**Expected Results:**
- Transient power oscillation (damped)
- GFM resynchronizes within 1-2 seconds
- VSM damping reduces oscillations
- No loss of stability
- Test outcome: "Stable"

**Output Plots:**
- Grid Phase Angle (step change)
- GFM Frequency (shows transient)
- Damping Power (VSM)
- Active & Reactive Power (oscillations then settling)
- Voltage and current waveforms

---

#### Français

**Description:** Saut soudain de 10 degrés d'angle de phase dans la tension du réseau pour tester la stabilité transitoire.

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid phase by 10 degrees';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Angle de Phase Initial: 0 degrés
- Angle de Phase Final: 10 degrés
- Type de Saut: Instantané (échelon)
- Temps du Saut: 3 secondes
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- Oscillation de puissance transitoire (amortie)
- Le GFM se resynchronise en 1-2 secondes
- L'amortissement VSM réduit les oscillations
- Pas de perte de stabilité
- Résultat du test: "Stable"

**Graphiques de Sortie:**
- Angle de Phase du Réseau (changement en échelon)
- Fréquence GFM (montre le transitoire)
- Puissance d'Amortissement (VSM)
- Puissance Active & Réactive (oscillations puis stabilisation)
- Formes d'onde de tension et courant

---

### Scenario 10: Grid Phase Jump (60 degrees) / Saut de Phase du Réseau (60 degrés)

#### English

**Description:** Severe 60-degree phase jump to test robustness under extreme transient conditions.

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid phase by 60 degrees';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Initial Phase Angle: 0 degrees
- Final Phase Angle: 60 degrees
- Jump Type: Instantaneous
- Jump Time: 3 seconds
- Simulation Time: ~8 seconds

**Expected Results:**
- Large transient power surge
- Current limiting may activate
- GFM resynchronizes (may take 2-4 seconds)
- Possible voltage dip during transient
- Test outcome: "Stable" (if well-tuned)

**Warning:** This is a severe test. Some parameter combinations may result in temporary instability.

---

#### Français

**Description:** Saut de phase sévère de 60 degrés pour tester la robustesse dans des conditions transitoires extrêmes.

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in grid phase by 60 degrees';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Angle de Phase Initial: 0 degrés
- Angle de Phase Final: 60 degrés
- Type de Saut: Instantané
- Temps du Saut: 3 secondes
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- Grande surtension transitoire de puissance
- La limitation de courant peut s'activer
- Le GFM se resynchronise (peut prendre 2-4 secondes)
- Creux de tension possible pendant le transitoire
- Résultat du test: "Stable" (si bien réglé)

**Avertissement:** C'est un test sévère. Certaines combinaisons de paramètres peuvent entraîner une instabilité temporaire.

---

### Scenario 11: Permanent Three-Phase Fault / Défaut Triphasé Permanent

#### English

**Description:** Sustained three-phase short circuit to test fault current contribution and current limiting.

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';  % or 'Current Limiting' or 'Virtual Impedance and Current Limiting'
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Permanent three-phase fault';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Fault Impedance: 0.05 pu (default, adjustable)
- Fault Start Time: 3 seconds (disturbanceTime)
- Fault Duration: Permanent (until simulation end)
- Fault Location: Grid side of transformer
- Simulation Time: ~8 seconds

**Expected Results:**
- Fault current: 2-3 pu (limited by current limiting method)
- Voltage collapse at fault point (near zero)
- GFM attempts to maintain operation
- Current limiting active throughout fault
- Test outcome: May be "Unstable" or "Faulted" (expected for permanent fault)

**Output Plots:**
- Fault Trigger Signal
- Fault Current Magnitude (Is)
- GFM Active & Reactive Power (drop during fault)
- Voltage at Fault (near zero)
- Current at Fault (high, limited)

**Current Limiting Methods:**
- **Virtual Impedance**: Smooth limiting, voltage drop
- **Current Limiting**: Hard saturation
- **Combined**: Best fault ride-through

---

#### Français

**Description:** Court-circuit triphasé soutenu pour tester la contribution au courant de défaut et la limitation de courant.

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';  % ou 'Current Limiting' ou 'Virtual Impedance and Current Limiting'
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Permanent three-phase fault';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Impédance de Défaut: 0.05 pu (par défaut, ajustable)
- Temps de Début de Défaut: 3 secondes (disturbanceTime)
- Durée du Défaut: Permanent (jusqu'à la fin de la simulation)
- Localisation du Défaut: Côté réseau du transformateur
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- Courant de défaut: 2-3 pu (limité par la méthode de limitation de courant)
- Effondrement de tension au point de défaut (proche de zéro)
- Le GFM tente de maintenir le fonctionnement
- Limitation de courant active pendant tout le défaut
- Résultat du test: Peut être "Unstable" ou "Faulted" (attendu pour défaut permanent)

**Graphiques de Sortie:**
- Signal de Déclenchement du Défaut
- Amplitude du Courant de Défaut (Is)
- Puissance Active & Réactive GFM (chute pendant le défaut)
- Tension au Défaut (proche de zéro)
- Courant au Défaut (élevé, limité)

**Méthodes de Limitation de Courant:**
- **Impédance Virtuelle**: Limitation douce, chute de tension
- **Limitation de Courant**: Saturation dure
- **Combiné**: Meilleure tenue au défaut

---

### Scenario 12: Temporary Three-Phase Fault / Défaut Triphasé Temporaire

#### English

**Description:** Transient three-phase fault that clears after 2 seconds (LVRT test).

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Temporary three-phase fault';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Fault Impedance: 0.05 pu
- Fault Start Time: 3 seconds
- Fault Duration: 2 seconds
- Fault Clearance: Automatic at t=5s
- Simulation Time: ~10 seconds

**Expected Results:**
- **During Fault (3-5s)**:
  - Current limiting active
  - Voltage sag to 0.1-0.3 pu
  - Power delivery reduced
- **After Clearance (5s+)**:
  - Voltage recovers to 0.9-1.0 pu
  - GFM resynchronizes with grid
  - Power restored to pre-fault levels
  - Meets LVRT requirements
- Test outcome: "Stable"

**Output Plots:**
- Fault Trigger Signal (on/off)
- Fault Current (spike then recovery)
- Active & Reactive Power (dip then recovery)
- Voltage at Fault (sag during, recovery after)
- Current at Fault (limited during, normal after)
- Voltage After Fault (recovery trajectory)
- Current After Fault (recovery trajectory)

**Grid Code Compliance:** Low Voltage Ride-Through (LVRT) per grid codes

---

#### Français

**Description:** Défaut triphasé transitoire qui s'efface après 2 secondes (test LVRT).

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Temporary three-phase fault';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Impédance de Défaut: 0.05 pu
- Temps de Début de Défaut: 3 secondes
- Durée du Défaut: 2 secondes
- Élimination du Défaut: Automatique à t=5s
- Temps de Simulation: ~10 secondes

**Résultats Attendus:**
- **Pendant le Défaut (3-5s)**:
  - Limitation de courant active
  - Creux de tension à 0.1-0.3 pu
  - Fourniture de puissance réduite
- **Après Élimination (5s+)**:
  - Tension récupère à 0.9-1.0 pu
  - Le GFM se resynchronise avec le réseau
  - Puissance restaurée aux niveaux pré-défaut
  - Conforme aux exigences LVRT
- Résultat du test: "Stable"

**Graphiques de Sortie:**
- Signal de Déclenchement du Défaut (on/off)
- Courant de Défaut (pointe puis récupération)
- Puissance Active & Réactive (creux puis récupération)
- Tension au Défaut (creux pendant, récupération après)
- Courant au Défaut (limité pendant, normal après)
- Tension Après Défaut (trajectoire de récupération)
- Courant Après Défaut (trajectoire de récupération)

**Conformité Code de Réseau:** Tenue aux Creux de Tension (LVRT) selon les codes de réseau

---

### Scenario 13: Islanding Condition / Condition d'Îlotage

#### English

**Description:** Circuit breaker opens, isolating GFM with local load (black-start test).

**How to Run:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Islanding condition';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Parameters:**
- Circuit Breaker Trip Time: 3 seconds
- Local Load (Before Island): Pload = 0.7 pu, Qload = 0.2 pu
- Local Load (After Island): Pload = 0.8 pu, Qload = 0.3 pu (may change)
- Island Duration: Remainder of simulation
- Simulation Time: ~8 seconds

**Expected Results:**
- **Before Islanding (0-3s)**:
  - Normal grid-connected operation
  - Grid and GFM share load
- **After Islanding (3s+)**:
  - GFM transitions to island mode autonomously
  - GFM supplies entire local load
  - Voltage maintained at 0.9-1.0 pu
  - Frequency maintained at 49.5-50.5 Hz
  - Black-start capability demonstrated
- Test outcome: "Stable"

**Output Plots:**
- Circuit Breaker Trip Signal
- GFM Frequency (autonomous control after trip)
- GFM Active Power (matches load)
- GFM Reactive Power (matches load)
- GFM Voltage (stable in island)
- GFM Current (supplies load)

**Real-World Applications:**
- Microgrid operation
- Grid resilience during outages
- Critical load supply
- Distributed Energy Resource (DER) autonomy

---

#### Français

**Description:** Le disjoncteur s'ouvre, isolant le GFM avec une charge locale (test de démarrage autonome).

**Comment Exécuter:**
```matlab
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Islanding condition';

outputTable = PlotGridFormingConverter(testCondition, 1);
```

**Paramètres:**
- Temps de Déclenchement du Disjoncteur: 3 secondes
- Charge Locale (Avant Îlotage): Pload = 0.7 pu, Qload = 0.2 pu
- Charge Locale (Après Îlotage): Pload = 0.8 pu, Qload = 0.3 pu (peut changer)
- Durée d'Îlotage: Reste de la simulation
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- **Avant Îlotage (0-3s)**:
  - Fonctionnement normal connecté au réseau
  - Réseau et GFM partagent la charge
- **Après Îlotage (3s+)**:
  - Le GFM transite en mode îloté de manière autonome
  - Le GFM alimente toute la charge locale
  - Tension maintenue à 0.9-1.0 pu
  - Fréquence maintenue à 49.5-50.5 Hz
  - Capacité de démarrage autonome démontrée
- Résultat du test: "Stable"

**Graphiques de Sortie:**
- Signal de Déclenchement du Disjoncteur
- Fréquence GFM (contrôle autonome après déclenchement)
- Puissance Active GFM (correspond à la charge)
- Puissance Réactive GFM (correspond à la charge)
- Tension GFM (stable en îlotage)
- Courant GFM (alimente la charge)

**Applications Réelles:**
- Fonctionnement en microréseau
- Résilience du réseau pendant les pannes
- Alimentation de charges critiques
- Autonomie des Ressources Énergétiques Distribuées (RED)

---

## Parametric Studies

## Études Paramétriques

---

### Study 1: Inertia Constant Effect / Effet de la Constante d'Inertie

#### English

**Description:** Sweep through different VSM inertia constants to study dynamic response.

**How to Run:**
```matlab
% Configure base test condition
testCondition.activePowerMethod = 'Virtual Synchronous Machine';  % Required for inertia
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in active power reference';  % Base scenario

% Define inertia constant array
inertiaConstantArray = [0.1, 0.4, 1, 3];  % seconds

% Run parametric study
outputTable = PlotInertiaConstantEffects(inertiaConstantArray, testCondition, 1);
```

**Parameters:**
- Inertia Constants: [0.1, 0.4, 1.0, 3.0] seconds
  - H = 0.1s: Very low inertia (typical inverter)
  - H = 0.4s: Low inertia
  - H = 1.0s: Medium inertia
  - H = 3.0s: High inertia (approaching synchronous machine)
- Base Scenario: Active power reference step change
- Simulation Time: ~8 seconds

**Expected Results:**
- **Lower H (0.1s)**:
  - Fast power response
  - Large frequency deviation (RoCoF)
  - Quick settling
  - Less inertial support
- **Higher H (3.0s)**:
  - Slower power response
  - Small frequency deviation
  - Better frequency stability
  - More inertial support (like synchronous machine)

**Output Plots:**
- Pref vs Pmeas for all H values (comparison)
- Inertia Power (Pinertia) for each H
- Reactive Power for each H
- Voltage Magnitude for each H
- Current Magnitude for each H

**Engineering Insight:**
- Trade-off between dynamic performance and grid support
- Higher H mimics synchronous machines (H = 2-10s typical)
- Lower H provides faster control response

---

#### Français

**Description:** Balayage de différentes constantes d'inertie VSM pour étudier la réponse dynamique.

**Comment Exécuter:**
```matlab
% Configurer la condition de test de base
testCondition.activePowerMethod = 'Virtual Synchronous Machine';  % Requis pour l'inertie
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in active power reference';  % Scénario de base

% Définir le tableau de constantes d'inertie
inertiaConstantArray = [0.1, 0.4, 1, 3];  % secondes

% Exécuter l'étude paramétrique
outputTable = PlotInertiaConstantEffects(inertiaConstantArray, testCondition, 1);
```

**Paramètres:**
- Constantes d'Inertie: [0.1, 0.4, 1.0, 3.0] secondes
  - H = 0.1s: Inertie très faible (onduleur typique)
  - H = 0.4s: Inertie faible
  - H = 1.0s: Inertie moyenne
  - H = 3.0s: Inertie élevée (proche de machine synchrone)
- Scénario de Base: Changement en échelon de référence de puissance active
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- **H Faible (0.1s)**:
  - Réponse rapide de la puissance
  - Grande déviation de fréquence (RoCoF)
  - Stabilisation rapide
  - Moins de support inertiel
- **H Élevé (3.0s)**:
  - Réponse lente de la puissance
  - Petite déviation de fréquence
  - Meilleure stabilité de fréquence
  - Plus de support inertiel (comme machine synchrone)

**Graphiques de Sortie:**
- Pref vs Pmeas pour toutes les valeurs de H (comparaison)
- Puissance d'Inertie (Pinertia) pour chaque H
- Puissance Réactive pour chaque H
- Amplitude de Tension pour chaque H
- Amplitude de Courant pour chaque H

**Aperçu d'Ingénierie:**
- Compromis entre performance dynamique et support réseau
- H élevé imite les machines synchrones (H = 2-10s typique)
- H faible fournit une réponse de contrôle plus rapide

---

### Study 2: Damping Coefficient Effect / Effet du Coefficient d'Amortissement

#### English

**Description:** Sweep through different VSM damping coefficients to study oscillation damping.

**How to Run:**
```matlab
% Configure base test condition
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in active power reference';

% Define damping coefficient array
dampingArray = [0.6, 2, 4];  % pu

% Run parametric study
outputTable = PlotDampingEffects(dampingArray, testCondition, 1);
```

**Parameters:**
- Damping Coefficients: [0.6, 2.0, 4.0] pu
  - D = 0.6 pu: Low damping (oscillatory)
  - D = 2.0 pu: Medium damping
  - D = 4.0 pu: High damping (critically damped)
- Base Scenario: Active power reference step change
- Simulation Time: ~8 seconds

**Expected Results:**
- **Lower D (0.6 pu)**:
  - Oscillatory response
  - Longer settling time (3-5 seconds)
  - Overshoot > 10%
  - Multiple oscillations
- **Higher D (4.0 pu)**:
  - Critically damped response
  - Fast settling time (0.5-1 second)
  - Minimal overshoot (< 5%)
  - No oscillations

**Output Plots:**
- Pref vs Pmeas for all D values
- Damping Power (Pdamping) for each D
- Reactive Power for each D
- Voltage Magnitude for each D
- Current Magnitude for each D

**Engineering Insight:**
- Optimal damping balances settling time and stability
- D too low: oscillatory, poor stability
- D too high: sluggish response
- Typical range: 1-3 pu

---

#### Français

**Description:** Balayage de différents coefficients d'amortissement VSM pour étudier l'amortissement des oscillations.

**Comment Exécuter:**
```matlab
% Configurer la condition de test de base
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Change in active power reference';

% Définir le tableau de coefficients d'amortissement
dampingArray = [0.6, 2, 4];  % pu

% Exécuter l'étude paramétrique
outputTable = PlotDampingEffects(dampingArray, testCondition, 1);
```

**Paramètres:**
- Coefficients d'Amortissement: [0.6, 2.0, 4.0] pu
  - D = 0.6 pu: Amortissement faible (oscillatoire)
  - D = 2.0 pu: Amortissement moyen
  - D = 4.0 pu: Amortissement élevé (critique)
- Scénario de Base: Changement en échelon de référence de puissance active
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- **D Faible (0.6 pu)**:
  - Réponse oscillatoire
  - Temps de stabilisation plus long (3-5 secondes)
  - Dépassement > 10%
  - Oscillations multiples
- **D Élevé (4.0 pu)**:
  - Réponse critique amortie
  - Temps de stabilisation rapide (0.5-1 seconde)
  - Dépassement minimal (< 5%)
  - Pas d'oscillations

**Graphiques de Sortie:**
- Pref vs Pmeas pour toutes les valeurs de D
- Puissance d'Amortissement (Pdamping) pour chaque D
- Puissance Réactive pour chaque D
- Amplitude de Tension pour chaque D
- Amplitude de Courant pour chaque D

**Aperçu d'Ingénierie:**
- L'amortissement optimal équilibre le temps de stabilisation et la stabilité
- D trop faible: oscillatoire, mauvaise stabilité
- D trop élevé: réponse lente
- Plage typique: 1-3 pu

---

### Study 3: Fault Impedance Effect / Effet de l'Impédance de Défaut

#### English

**Description:** Sweep through different three-phase fault impedances to study fault severity.

**How to Run:**
```matlab
% Configure base test condition
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Permanent three-phase fault';

% Define fault impedance array
faultImpedanceArray = [0.05, 0.1, 0.25, 0.4];  % pu

% Run parametric study
outputTable = PlotFaultCurrentVoltageEffects(faultImpedanceArray, testCondition, 1);
```

**Parameters:**
- Fault Impedances: [0.05, 0.1, 0.25, 0.4] pu
  - Zf = 0.05 pu: Severe fault (bolted fault)
  - Zf = 0.1 pu: Moderate fault
  - Zf = 0.25 pu: Light fault
  - Zf = 0.4 pu: Very light fault
- Base Scenario: Permanent three-phase fault
- Simulation Time: ~8 seconds

**Expected Results:**
- **Lower Zf (0.05 pu)**:
  - Highest fault current (3-4 pu)
  - Deepest voltage sag (< 0.1 pu)
  - Maximum stress on current limiting
- **Higher Zf (0.4 pu)**:
  - Lower fault current (1-2 pu)
  - Shallower voltage sag (0.5-0.6 pu)
  - Less stress on converter

**Output Plots:**
- Fault Current vs Zf
- Voltage Sag Depth vs Zf
- Power Flow vs Zf

**Engineering Insight:**
- Tests current limiting effectiveness across fault severity spectrum
- Validates protection system performance

---

#### Français

**Description:** Balayage de différentes impédances de défaut triphasé pour étudier la sévérité du défaut.

**Comment Exécuter:**
```matlab
% Configurer la condition de test de base
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Permanent three-phase fault';

% Définir le tableau d'impédances de défaut
faultImpedanceArray = [0.05, 0.1, 0.25, 0.4];  % pu

% Exécuter l'étude paramétrique
outputTable = PlotFaultCurrentVoltageEffects(faultImpedanceArray, testCondition, 1);
```

**Paramètres:**
- Impédances de Défaut: [0.05, 0.1, 0.25, 0.4] pu
  - Zf = 0.05 pu: Défaut sévère (défaut franc)
  - Zf = 0.1 pu: Défaut modéré
  - Zf = 0.25 pu: Défaut léger
  - Zf = 0.4 pu: Défaut très léger
- Scénario de Base: Défaut triphasé permanent
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- **Zf Faible (0.05 pu)**:
  - Courant de défaut le plus élevé (3-4 pu)
  - Creux de tension le plus profond (< 0.1 pu)
  - Contrainte maximale sur la limitation de courant
- **Zf Élevé (0.4 pu)**:
  - Courant de défaut plus faible (1-2 pu)
  - Creux de tension moins profond (0.5-0.6 pu)
  - Moins de contrainte sur le convertisseur

**Graphiques de Sortie:**
- Courant de Défaut vs Zf
- Profondeur de Creux de Tension vs Zf
- Flux de Puissance vs Zf

**Aperçu d'Ingénierie:**
- Teste l'efficacité de la limitation de courant sur le spectre de sévérité des défauts
- Valide la performance du système de protection

---

### Study 4: Current Limiting Method Comparison / Comparaison des Méthodes de Limitation de Courant

#### English

**Description:** Compare three current limiting strategies during permanent fault.

**How to Run:**
```matlab
% Configure base test condition
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';  % Initial (will be overridden)
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Permanent three-phase fault';

% Run comparison (tests all three methods automatically)
outputTable = PlotCompareFaultRideThroughMethod(testCondition, 1);
```

**Methods Compared:**
1. **Virtual Impedance Only**
   - Adds virtual series impedance during fault
   - Smooth current limiting
   - Voltage drop proportional to current

2. **Current Limiting Only**
   - Direct current magnitude saturation
   - Hard limiting at Imax
   - May cause control issues

3. **Virtual Impedance + Current Limiting (Combined)**
   - Best of both methods
   - Virtual impedance primary, current limiting backup
   - Robust fault ride-through

**Parameters:**
- Fault Impedance: 0.05 pu (severe)
- Fault Duration: Permanent
- Simulation Time: ~8 seconds

**Expected Results:**
- **Virtual Impedance**:
  - Current: 2-2.5 pu
  - Smooth waveforms
  - Gradual voltage drop

- **Current Limiting**:
  - Current: Exactly at limit (2 pu)
  - Possible waveform distortion
  - Abrupt limiting action

- **Combined**:
  - Current: 2-2.5 pu
  - Best waveform quality
  - Most robust

**Output Plots (3 columns, one per method):**
- GFM Peak Current
- Current Waveforms during fault
- Voltage Waveforms during fault

**Recommendation:** Use "Virtual Impedance and Current Limiting" for best performance.

---

#### Français

**Description:** Comparer trois stratégies de limitation de courant pendant un défaut permanent.

**Comment Exécuter:**
```matlab
% Configurer la condition de test de base
testCondition.activePowerMethod = 'Virtual Synchronous Machine';
testCondition.currentLimitMethod = 'Virtual Impedance';  % Initial (sera remplacé)
testCondition.SCR = 2.5;
testCondition.XbyR = 5;
testCondition.testCondition = 'Permanent three-phase fault';

% Exécuter la comparaison (teste automatiquement les trois méthodes)
outputTable = PlotCompareFaultRideThroughMethod(testCondition, 1);
```

**Méthodes Comparées:**
1. **Impédance Virtuelle Seulement**
   - Ajoute une impédance série virtuelle pendant le défaut
   - Limitation de courant douce
   - Chute de tension proportionnelle au courant

2. **Limitation de Courant Seulement**
   - Saturation directe de l'amplitude du courant
   - Limitation dure à Imax
   - Peut causer des problèmes de contrôle

3. **Impédance Virtuelle + Limitation de Courant (Combiné)**
   - Meilleur des deux méthodes
   - Impédance virtuelle primaire, limitation de courant secondaire
   - Tenue au défaut robuste

**Paramètres:**
- Impédance de Défaut: 0.05 pu (sévère)
- Durée du Défaut: Permanent
- Temps de Simulation: ~8 secondes

**Résultats Attendus:**
- **Impédance Virtuelle**:
  - Courant: 2-2.5 pu
  - Formes d'onde lisses
  - Chute de tension progressive

- **Limitation de Courant**:
  - Courant: Exactement à la limite (2 pu)
  - Distorsion possible des formes d'onde
  - Action de limitation abrupte

- **Combiné**:
  - Courant: 2-2.5 pu
  - Meilleure qualité de forme d'onde
  - Plus robuste

**Graphiques de Sortie (3 colonnes, une par méthode):**
- Courant de Pointe GFM
- Formes d'onde de Courant pendant le défaut
- Formes d'onde de Tension pendant le défaut

**Recommandation:** Utiliser "Virtual Impedance and Current Limiting" pour la meilleure performance.

---

## Automated Testing

## Tests Automatisés

#### English

**Description:** Run MATLAB unit tests to validate all functionalities automatically.

**How to Run All Tests:**
```matlab
% Navigate to project root
cd('/path/to/Zaid_Power-Converter-Circuit-Control-Simscape')

% Open project
openProject('PowerConverterCircuitAndControlDesignWithSimscape.prj')

% Run test suite
testrunnerGridFormingConverter
```

**Test Categories:**

1. **Unit Tests** (`Tests/GridFormingConverterUnit.m`):
   - Model simulation test
   - All 13 scenario plot tests
   - Inertia constant effect test
   - Damping effect test
   - Fault impedance effect test
   - Current limiting comparison test

2. **System Tests** (`Tests/GridFormingConverterSystem.m`):
   - Active power tracking (VSM & Droop)
   - Reactive power tracking (VSM & Droop)
   - Frequency change stability
   - Phase jump stability (60°)
   - Islanding stability
   - Current limiting variants (3 methods × fault test)

**Test Outputs:**
- Test results: `Tests/GFM_TestResults_R2023b.xml`
- Code coverage: `coverage-GFMCodeCoverage/`
- Pass/Fail summary in MATLAB Command Window

**Expected Runtime:** 30-60 minutes (all tests)

---

#### Français

**Description:** Exécuter des tests unitaires MATLAB pour valider automatiquement toutes les fonctionnalités.

**Comment Exécuter Tous les Tests:**
```matlab
% Naviguer vers la racine du projet
cd('/chemin/vers/Zaid_Power-Converter-Circuit-Control-Simscape')

% Ouvrir le projet
openProject('PowerConverterCircuitAndControlDesignWithSimscape.prj')

% Exécuter la suite de tests
testrunnerGridFormingConverter
```

**Catégories de Tests:**

1. **Tests Unitaires** (`Tests/GridFormingConverterUnit.m`):
   - Test de simulation du modèle
   - Tests de tracé des 13 scénarios
   - Test d'effet de constante d'inertie
   - Test d'effet d'amortissement
   - Test d'effet d'impédance de défaut
   - Test de comparaison de limitation de courant

2. **Tests Système** (`Tests/GridFormingConverterSystem.m`):
   - Suivi de puissance active (VSM & Droop)
   - Suivi de puissance réactive (VSM & Droop)
   - Stabilité de changement de fréquence
   - Stabilité de saut de phase (60°)
   - Stabilité d'îlotage
   - Variantes de limitation de courant (3 méthodes × test de défaut)

**Sorties de Test:**
- Résultats de test: `Tests/GFM_TestResults_R2023b.xml`
- Couverture de code: `coverage-GFMCodeCoverage/`
- Résumé Réussite/Échec dans la fenêtre de commande MATLAB

**Durée d'Exécution Attendue:** 30-60 minutes (tous les tests)

---

## Configuration Parameters

## Paramètres de Configuration

### English

**Key Configuration Parameters:**

```matlab
% Power Control Method
testCondition.activePowerMethod = 'Virtual Synchronous Machine';  % or 'Droop Control'

% Current Limiting Method
testCondition.currentLimitMethod = 'Virtual Impedance';
% Options: 'Virtual Impedance', 'Current Limiting', 'Virtual Impedance and Current Limiting'

% Grid Strength
testCondition.SCR = 2.5;  % Short Circuit Ratio (typical: 2-10)
% SCR < 3: Weak grid
% SCR 3-10: Medium grid
% SCR > 10: Strong grid

% Grid Impedance Characteristics
testCondition.XbyR = 5;  % X/R ratio (typical: 3-10 for transmission, 1-3 for distribution)

% Scenario Selection
testCondition.testCondition = 'Normal operation';  % See full list in scenarios section
```

**Advanced Parameters (in GridFormingConverterInputParameters.mlx):**

```matlab
% VSM Parameters
gridInverter.vsm.inertiaConstant = 1;  % seconds (H)
gridInverter.vsm.dampingCoefficient = 2;  % pu (D)

% Droop Parameters
gridInverter.droop.frequencyDroop = 0.05;  % pu (typical: 0.03-0.06)
gridInverter.droop.voltageDroop = 0.05;  % pu

% Current Limiting
gridInverter.currentLimit.maxCurrent = 2;  % pu
gridInverter.virtualImpedance.resistance = 0.1;  % pu
gridInverter.virtualImpedance.reactance = 0.5;  % pu

% Converter Ratings
gridInverter.ratedPower = 1e6;  % VA (1 MVA default)
gridInverter.ratedVoltage = 415;  % V (line-to-line)
gridInverter.ratedFrequency = 50;  % Hz

% DC Link
gridInverter.dcVoltage = 800;  % V

% Filter (LCL)
gridInverter.filter.Lc = 0.15;  % pu (converter-side inductor)
gridInverter.filter.Lg = 0.15;  % pu (grid-side inductor)
gridInverter.filter.Cf = 0.066;  % pu (filter capacitor)
gridInverter.filter.Rd = 0.005;  % pu (damping resistor)
```

---

### Français

**Paramètres de Configuration Clés:**

```matlab
% Méthode de Contrôle de Puissance
testCondition.activePowerMethod = 'Virtual Synchronous Machine';  % ou 'Droop Control'

% Méthode de Limitation de Courant
testCondition.currentLimitMethod = 'Virtual Impedance';
% Options: 'Virtual Impedance', 'Current Limiting', 'Virtual Impedance and Current Limiting'

% Force du Réseau
testCondition.SCR = 2.5;  % Ratio de Court-Circuit (typique: 2-10)
% SCR < 3: Réseau faible
% SCR 3-10: Réseau moyen
% SCR > 10: Réseau fort

% Caractéristiques d'Impédance du Réseau
testCondition.XbyR = 5;  % Ratio X/R (typique: 3-10 pour transport, 1-3 pour distribution)

% Sélection de Scénario
testCondition.testCondition = 'Normal operation';  % Voir liste complète dans section scénarios
```

**Paramètres Avancés (dans GridFormingConverterInputParameters.mlx):**

```matlab
% Paramètres VSM
gridInverter.vsm.inertiaConstant = 1;  % secondes (H)
gridInverter.vsm.dampingCoefficient = 2;  % pu (D)

% Paramètres Droop
gridInverter.droop.frequencyDroop = 0.05;  % pu (typique: 0.03-0.06)
gridInverter.droop.voltageDroop = 0.05;  % pu

% Limitation de Courant
gridInverter.currentLimit.maxCurrent = 2;  % pu
gridInverter.virtualImpedance.resistance = 0.1;  % pu
gridInverter.virtualImpedance.reactance = 0.5;  % pu

% Caractéristiques Nominales du Convertisseur
gridInverter.ratedPower = 1e6;  % VA (1 MVA par défaut)
gridInverter.ratedVoltage = 415;  % V (ligne-à-ligne)
gridInverter.ratedFrequency = 50;  % Hz

% Lien DC
gridInverter.dcVoltage = 800;  % V

% Filtre (LCL)
gridInverter.filter.Lc = 0.15;  % pu (inductance côté convertisseur)
gridInverter.filter.Lg = 0.15;  % pu (inductance côté réseau)
gridInverter.filter.Cf = 0.066;  % pu (condensateur de filtre)
gridInverter.filter.Rd = 0.005;  % pu (résistance d'amortissement)
```

---

## Troubleshooting

## Dépannage

### English

**Common Issues and Solutions:**

1. **Error: "Undefined function or variable 'testCondition'"**
   - **Solution**: Run `GridFormingConverterInputParameters.mlx` first
   ```matlab
   run('Script_Data/GridFormingConverterInputParameters.mlx')
   ```

2. **Error: "Model GridFormingConverter not found"**
   - **Solution**: Open the MATLAB project first
   ```matlab
   openProject('PowerConverterCircuitAndControlDesignWithSimscape.prj')
   ```

3. **Simulation runs very slowly**
   - **Solution**: Check solver settings, reduce simulation time, or use faster computer
   - Try changing solver to 'ode23t' (faster but less accurate)

4. **Test outcome shows "Unstable"**
   - **Possible Causes**:
     - SCR too low (< 2): Try increasing SCR
     - Damping too low: Increase damping coefficient
     - Inertia too low: Increase inertia constant
     - Severe fault scenario: May be expected for permanent faults

5. **Plots are not appearing**
   - **Solution**: Ensure `plotFlag = 1` in function calls
   ```matlab
   outputTable = PlotGridFormingConverter(testCondition, 1);  % 1 enables plotting
   ```

6. **Error: "License checkout failed for Simscape Electrical"**
   - **Solution**: Ensure you have the required toolboxes installed and licensed

7. **Different results from documentation**
   - **Possible Causes**:
     - Different MATLAB version (use R2023a or later)
     - Parameters modified in input scripts
     - Different grid conditions (SCR, X/R)

**For More Help:**
- Check MATLAB documentation: `doc SimulationInput`
- MathWorks support: https://www.mathworks.com/support

---

### Français

**Problèmes Courants et Solutions:**

1. **Erreur: "Fonction ou variable 'testCondition' non définie"**
   - **Solution**: Exécutez d'abord `GridFormingConverterInputParameters.mlx`
   ```matlab
   run('Script_Data/GridFormingConverterInputParameters.mlx')
   ```

2. **Erreur: "Modèle GridFormingConverter introuvable"**
   - **Solution**: Ouvrez d'abord le projet MATLAB
   ```matlab
   openProject('PowerConverterCircuitAndControlDesignWithSimscape.prj')
   ```

3. **La simulation s'exécute très lentement**
   - **Solution**: Vérifiez les paramètres du solveur, réduisez le temps de simulation, ou utilisez un ordinateur plus rapide
   - Essayez de changer le solveur en 'ode23t' (plus rapide mais moins précis)

4. **Le résultat du test indique "Unstable"**
   - **Causes Possibles**:
     - SCR trop faible (< 2): Essayez d'augmenter le SCR
     - Amortissement trop faible: Augmentez le coefficient d'amortissement
     - Inertie trop faible: Augmentez la constante d'inertie
     - Scénario de défaut sévère: Peut être attendu pour les défauts permanents

5. **Les graphiques n'apparaissent pas**
   - **Solution**: Assurez-vous que `plotFlag = 1` dans les appels de fonction
   ```matlab
   outputTable = PlotGridFormingConverter(testCondition, 1);  % 1 active le tracé
   ```

6. **Erreur: "Échec d'extraction de licence pour Simscape Electrical"**
   - **Solution**: Assurez-vous d'avoir les toolboxes requis installés et sous licence

7. **Résultats différents de la documentation**
   - **Causes Possibles**:
     - Version MATLAB différente (utilisez R2023a ou ultérieur)
     - Paramètres modifiés dans les scripts d'entrée
     - Conditions de réseau différentes (SCR, X/R)

**Pour Plus d'Aide:**
- Consultez la documentation MATLAB: `doc SimulationInput`
- Support MathWorks: https://www.mathworks.com/support

---

## Quick Reference Tables / Tableaux de Référence Rapide

### All Scenarios Summary / Résumé de Tous les Scénarios

| # | Scenario Name / Nom du Scénario | Test Condition String | Simulation Time (s) |
|---|--------------------------------|----------------------|---------------------|
| 1 | Normal Operation / Opération Normale | `'Normal operation'` | ~5 |
| 2 | Active Power Change / Changement Puissance Active | `'Change in active power reference'` | ~8 |
| 3 | Reactive Power Change / Changement Puissance Réactive | `'Change in reactive power reference'` | ~8 |
| 4 | Grid Voltage Change / Changement Tension Réseau | `'Change in grid voltage'` | ~8 |
| 5 | Local Load Change / Changement Charge Locale | `'Change in local load'` | ~8 |
| 6 | Small Frequency Change / Petit Changement Fréquence | `'Change in grid frequency 1Hz/s, +0.5Hz'` | ~8 |
| 7 | Large Frequency Change / Grand Changement Fréquence | `'Change in grid frequency 2Hz/s, +2Hz'` | ~8 |
| 8 | Full Frequency Range (GC0137) / Plage Fréquence Complète | `'Change in grid frequency 2Hz/s, +2Hz and 1Hz/s till -5Hz'` | ~20 |
| 9 | Phase Jump 10° / Saut Phase 10° | `'Change in grid phase by 10 degrees'` | ~8 |
| 10 | Phase Jump 60° / Saut Phase 60° | `'Change in grid phase by 60 degrees'` | ~8 |
| 11 | Permanent Fault / Défaut Permanent | `'Permanent three-phase fault'` | ~8 |
| 12 | Temporary Fault (LVRT) / Défaut Temporaire | `'Temporary three-phase fault'` | ~10 |
| 13 | Islanding / Îlotage | `'Islanding condition'` | ~8 |

---

### Control Methods / Méthodes de Contrôle

| Method / Méthode | String Value | Features / Caractéristiques |
|------------------|--------------|------------------------------|
| Virtual Synchronous Machine | `'Virtual Synchronous Machine'` | Inertia (H), Damping (D), Mimics SG |
| Droop Control | `'Droop Control'` | f-P droop, V-Q droop, Simple |

---

### Current Limiting Methods / Méthodes de Limitation de Courant

| Method / Méthode | String Value | Best For / Meilleur Pour |
|------------------|--------------|---------------------------|
| Virtual Impedance | `'Virtual Impedance'` | Smooth limiting / Limitation douce |
| Current Limiting | `'Current Limiting'` | Direct control / Contrôle direct |
| Combined / Combiné | `'Virtual Impedance and Current Limiting'` | **Recommended** / **Recommandé** |

---

## Contact and Support / Contact et Support

### English
- **GitHub Issues**: https://github.com/pscadmmc-glitch/Zaid_Power-Converter-Circuit-Control-Simscape/issues
- **MathWorks File Exchange**: https://www.mathworks.com/matlabcentral/fileexchange/131783
- **Documentation**: See `Overview/PowerConverterCircuitAndControlDesignCoverPage.html`

### Français
- **Issues GitHub**: https://github.com/pscadmmc-glitch/Zaid_Power-Converter-Circuit-Control-Simscape/issues
- **MathWorks File Exchange**: https://www.mathworks.com/matlabcentral/fileexchange/131783
- **Documentation**: Voir `Overview/PowerConverterCircuitAndControlDesignCoverPage.html`

---

## License / Licence

Copyright (c) 2023, The MathWorks, Inc.
All rights reserved. See `License.txt` for full details.

---

**Last Updated / Dernière Mise à Jour:** 2025-01-22
**Version:** 1.0
**MATLAB Version / Version MATLAB:** R2023a+
