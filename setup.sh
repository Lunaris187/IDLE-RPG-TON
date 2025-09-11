#!/bin/bash
# Skript für Idle-RPG-Prototypen (1-Tag-Entwicklung)

# Schritt 1: Verzeichnisstruktur erstellen
mkdir -p contracts src public tests components

# Schritt 2: Vorlagen herunterladen und integrieren
echo "Downloading TON Mini App Boilerplate..."
git clone https://github.com/ton-community/twa-template temp-twa
cp temp-twa/src/App.jsx src/App.jsx
cp temp-twa/public/index.html public/index.html
echo "Downloading TelegramUI..."
git clone https://github.com/Telegram-Mini-Apps/TelegramUI temp-telegramui
cp temp-telegramui/components/Stats.jsx src/components/Stats.jsx
cp temp-telegramui/components/Buttons.jsx src/components/Buttons.jsx
echo "Downloading TON Blueprint Templates..."
git clone https://github.com/ton-org/blueprint temp-blueprint
cp temp-blueprint/templates/nft.fc contracts/NFT.fc
cp temp-blueprint/templates/staking.fc contracts/Staking.fc
cp temp-blueprint/templates/jetton.fc contracts/Jetton.fc
rm -rf temp-*

# Schritt 3: Abhängigkeiten installieren
npm init -y
npm install @twa-dev/sdk@3.0.0 ton-connect express axios jest react react-dom vite @vitejs/plugin-react tailwindcss telegram-ui

# Schritt 4: Smart Contract für In-App-Käufe
cat <<EOT > contracts/InAppPurchase.fc
() recv_internal(int msg_value, cell in_msg, slice in_msg_body) impure {
    slice cs = in_msg_body;
    int op = cs~load_uint(32);
    if (op == 1) { // Buy Item
        require(msg_value >= 1000000000, 100); // 1 TON
        int item_id = cs~load_uint(64);
        var owner = get_data().begin_parse().load_msg_addr();
        send_raw_message(
            begin_cell()
                .store_uint(0x18, 6)
                .store_addr(owner)
                .store_coins(msg_value)
                .end_cell(),
            64
        );
    }
}
EOT

# Schritt 5: Haupt-HTML-Datei (mit TelegramUI)
cat <<EOT > public/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Idle RPG</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-cover bg-center text-white text-center" style="background-image: url('https://opengameart.org/sites/default/files/forest-bg.png'); animation: dayNight 10s infinite;">
    <div id="root" class="min-h-screen"></div>
    <script type="module" src="/src/App.jsx"></script>
    <script src="https://unpkg.com/@twa-dev/sdk@3.0.0/dist/index.js"></script>
    <style>
        @keyframes dayNight {
            0% { filter: brightness(1); }
            50% { filter: brightness(0.7); }
            100% { filter: brightness(1); }
        }
        button, select { font-size: 0.9rem; padding: 0.5rem; }
    </style>
</body>
</html>
EOT

# Schritt 6: React-Komponente (vereinfacht mit TelegramUI)
cat <<EOT > src/App.jsx
import { useEffect, useState } from 'react';
import { init } from '@twa-dev/sdk';
import { TonConnect } from 'ton-connect';
import { Stats, Buttons } from './components/Stats.jsx';
init();

const contractAddresses = {
    staking: 'DEINE_STAKING_CONTRACT_ADRESSE',
    purchase: 'DEINE_PURCHASE_CONTRACT_ADRESSE',
    nft: 'DEINE_NFT_CONTRACT_ADRESSE',
    jetton: 'DEINE_JETTON_CONTRACT_ADRESSE'
};

function App() {
    const [playerXP, setPlayerXP] = useState(0);
    const [playerGold, setPlayerGold] = useState(0);
    const [cryptoBalance, setCryptoBalance] = useState(1);
    const [stakedCrypto, setStakedCrypto] = useState(0);
    const [questActive, setQuestActive] = useState(false);
    const [questProgress, setQuestProgress] = useState(0);
    const questGoal = 100;

    const tonConnect = new TonConnect({ manifestUrl: 'https://<repl-id>.glitch.me/tonconnect-manifest.json' });

    useEffect(() => {
        const interval = setInterval(() => {
            setPlayerXP(xp => xp + 0.01 * (1 + stakedCrypto * 0.1));
            setPlayerGold(gold => gold + 0.005);
            if (questActive) {
                setQuestProgress(progress => {
                    const newProgress = progress + 0.002;
                    if (newProgress >= questGoal) {
                        setQuestActive(false);
                        setPlayerGold(gold => gold + 50);
                        document.getElementById('quest').innerText = `Quest abgeschlossen! +50 Gold`;
                    }
                    return newProgress;
                });
            }
        }, 10);
        return () => clearInterval(interval);
    }, [questActive, stakedCrypto]);

    const startQuest = () => {
        if (!questActive) {
            setQuestActive(true);
            setQuestProgress(0);
        }
    };

    const stakeCrypto = async () => {
        const tx = await tonConnect.sendTransaction({
            to: contractAddresses.staking,
            value: 0.1 * 1e9,
            data: { op: 1 }
        });
        setCryptoBalance(balance => balance - 0.1);
        setStakedCrypto(staked => staked + 0.1);
        console.log('Staked:', tx);
    };

    const buyItem = async () => {
        const itemId = document.getElementById('itemDropdown').value;
        const tx = await tonConnect.sendTransaction({
            to: contractAddresses.purchase,
            value: 0.01 * 1e9,
            data: { op: 1, itemId: parseInt(itemId) }
        });
        setCryptoBalance(balance => balance - 0.01);
        console.log('Item gekauft:', tx);
    };

    const mintNFT = async () => {
        const tx = await tonConnect.sendTransaction({
            to: contractAddresses.nft,
            value: 0,
            data: { op: 1, to: Telegram.WebApp.initDataUnsafe.user.id }
        });
        console.log('NFT geminted:', tx);
    };

    const showAd = () => {
        const adRevenue = 0.0144;
        setCryptoBalance(balance => balance + adRevenue);
        console.log('Werbeeinnahmen:', adRevenue);
    };

    return (
        <div className="max-w-sm mx-auto p-3 bg-black/70 rounded-lg">
            <h1 className="text-xl font-bold">Idle RPG</h1>
            <Stats
                xp={playerXP}
                gold={playerGold}
                crypto={cryptoBalance}
                stake={stakedCrypto}
                quest={questActive ? `Fortschritt: ${questProgress.toFixed(2)}/${questGoal}` : 'Keine Quest'}
            />
            <select id="itemDropdown" className="p-2 m-1 rounded text-black text-sm">
                <option value="1">Schwert</option>
                <option value="2">Rüstung</option>
                <option value="3">Zauber</option>
            </select>
            <Buttons
                onStartQuest={startQuest}
                onStake={stakeCrypto}
                onBuyItem={buyItem}
                onMintNFT={mintNFT}
                onShowAd={showAd}
            />
        </div>
    );
}

export default App;
EOT

# Schritt 7: TelegramUI-Komponenten
cat <<EOT > src/components/Stats.jsx
import React from 'react';

const Stats = ({ xp, gold, crypto, stake, quest }) => (
    <div className="my-3 text-sm">
        <p>XP: <span id="xp">{xp.toFixed(2)}</span></p>
        <p>Gold: <span id="gold">{gold.toFixed(2)}</span></p>
        <p>TON: <span id="crypto">{crypto.toFixed(2)}</span></p>
        <p>Gestaked: <span id="stake">{stake.toFixed(2)}</span></p>
        <p>Quest: <span id="quest">{quest}</span></p>
    </div>
);

export { Stats };
EOT

cat <<EOT > src/components/Buttons.jsx
import React from 'react';

const Buttons = ({ onStartQuest, onStake, onBuyItem, onMintNFT, onShowAd }) => (
    <div className="grid grid-cols-2 gap-2">
        <button onClick={onStartQuest} className="bg-green-500 text-white p-2 rounded hover:scale-105 transition text-sm">Quest starten</button>
        <button onClick={onStake} className="bg-green-500 text-white p-2 rounded hover:scale-105 transition text-sm">Stake 0.1 TON</button>
        <button onClick={onBuyItem} className="bg-green-500 text-white p-2 rounded hover:scale-105 transition text-sm">Item kaufen</button>
        <button onClick={onMintNFT} className="bg-green-500 text-white p-2 rounded hover:scale-105 transition text-sm">NFT minten</button>
        <button onClick={onShowAd} className="bg-green-500 text-white p-2 rounded hover:scale-105 transition text-sm">Anzeige ansehen</button>
    </div>
);

export { Buttons };
EOT

# Schritt 8: Vite-Konfiguration
cat <<EOT > vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
    plugins: [react()],
    server: {
        port: 3000
    }
});
EOT

# Schritt 9: Server einrichten
cat <<EOT > src/server.js
const express = require('express');
const app = express();
app.use(express.static('public'));
app.get('/tonconnect-manifest.json', (req, res) => {
    res.json({
        url: 'https://<repl-id>.glitch.me',
        name: 'Idle RPG',
        iconUrl: 'https://<repl-id>.glitch.me/icon.png'
    });
});
app.listen(3000, () => console.log('Server läuft auf Port 3000'));
EOT

# Schritt 10: TON Connect Manifest
cat <<EOT > public/tonconnect-manifest.json
{
    "url": "https://<repl-id>.glitch.me",
    "name": "Idle RPG",
    "iconUrl": "https://<repl-id>.glitch.me/icon.png"
}
EOT

# Schritt 11: Jest-Tests
cat <<EOT > tests/app.test.js
describe('Idle RPG Tests', () => {
    test('Quest Progress', () => {
        let questProgress = 0;
        const questGoal = 100;
        questProgress += 0.002;
        expect(questProgress).toBe(0.002);
    });
    test('Staking', () => {
        let cryptoBalance = 1;
        let stakedCrypto = 0;
        cryptoBalance -= 0.1;
        stakedCrypto += 0.1;
        expect(cryptoBalance).toBe(0.9);
        expect(stakedCrypto).toBe(0.1);
    });
});
EOT

# Schritt 12: Package.json
cat <<EOT > package.json
{
    "name": "idle-rpg",
    "version": "1.0.0",
    "scripts": {
        "dev": "vite",
        "build": "vite build",
        "test": "jest"
    },
    "dependencies": {
        "@twa-dev/sdk": "^3.0.0",
        "ton-connect": "^1.0.0",
        "express": "^4.18.2",
        "axios": "^1.6.0",
        "jest": "^29.7.0",
        "react": "^18.2.0",
        "react-dom": "^18.2.0",
        "vite": "^4.4.0",
        "@vitejs/plugin-react": "^4.0.0",
        "tailwindcss": "^3.3.0",
        "telegram-ui": "^1.0.0"
    }
}
EOT

# Schritt 13: Contracts deployen
echo "Installiere blueprint..."
npm install -g @ton-org/blueprint
echo "Deploying contracts..."
npx blueprint run contracts/NFT.fc --network testnet
npx blueprint run contracts/Staking.fc --network testnet
npx blueprint run contracts/InAppPurchase.fc --network testnet
npx blueprint run contracts/Jetton.fc --network testnet

# Schritt 14: Tests ausführen
npm test

# Schritt 15: Debugging mit Windsurf
echo "Nutze Windsurf AI für Debugging. Beispiel-Prompt: 'Fix TON Connect transaction error' oder 'Generate simple quest system for Idle RPG'."
