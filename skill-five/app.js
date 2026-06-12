const game = new GomokuGame();
const boardElement = document.getElementById('board');
const statusElement = document.getElementById('status');
const player1Info = document.getElementById('player1-info');
const player2Info = document.getElementById('player2-info');
const restartBtn = document.getElementById('restart-btn');
const infoBtn = document.getElementById('info-btn');
const infoModal = document.getElementById('info-modal');
const closeModal = document.getElementById('close-modal');
const restartModal = document.getElementById('restart-modal');
const closeRestartModal = document.getElementById('close-restart-modal');
const cancelRestartBtn = document.getElementById('cancel-restart');
const confirmRestartBtn = document.getElementById('confirm-restart');
const mountainPullModal = document.getElementById('mountain-pull-modal');
const closeMountainPullModal = document.getElementById('close-mountain-pull-modal');
const cancelMountainPullBtn = document.getElementById('cancel-mountain-pull');
const confirmMountainPullBtn = document.getElementById('confirm-mountain-pull');
const modeSelectModal = document.getElementById('mode-select-modal');
const closeModeSelectModal = document.getElementById('close-mode-select-modal');
const pvpBtn = document.getElementById('pvp-btn');
const pveBtn = document.getElementById('pve-btn');

function initBoard() {
    boardElement.innerHTML = '';
    for (let row = 0; row < game.boardSize; row++) {
        for (let col = 0; col < game.boardSize; col++) {
            const cell = document.createElement('div');
            cell.className = 'cell';
            cell.dataset.row = row;
            cell.dataset.col = col;
            cell.addEventListener('click', handleCellClick);
            boardElement.appendChild(cell);
        }
    }
}

function updateBoard() {
    const cells = boardElement.querySelectorAll('.cell');
    cells.forEach(cell => {
        const row = parseInt(cell.dataset.row);
        const col = parseInt(cell.dataset.col);
        const value = game.board[row][col];
        
        cell.innerHTML = '';
        cell.classList.remove('skill-target');
        
        // 添加hover指示器
        const hoverIndicator = document.createElement('div');
        hoverIndicator.className = 'hover-indicator';
        cell.appendChild(hoverIndicator);
        
        if (value !== 0) {
            const piece = document.createElement('div');
            piece.className = `piece ${value === 1 ? 'black' : 'white'}`;
            cell.appendChild(piece);
        }
    });
}

function updateStatus() {
    if (game.gameOver) {
        const winner = game.currentPlayer === 1 ? '⚫ 黑棋' : '⚪ 白棋';
        statusElement.textContent = `🎉 ${winner}获胜！`;
        statusElement.style.background = 'rgba(76, 175, 80, 0.8)';
    } else if (game.skipNextTurn) {
        statusElement.textContent = `${game.skipPlayer === 1 ? '⚫ 黑棋' : '⚪ 白棋'}回合被跳过！`;
        statusElement.style.background = 'rgba(255, 152, 0, 0.8)';
    } else {
        statusElement.textContent = `${game.currentPlayer === 1 ? '⚫ 黑棋' : '⚪ 白棋'}回合`;
        statusElement.style.background = 'rgba(0, 0, 0, 0.3)';
    }
    
    // 更新玩家信息高亮
    player1Info.classList.toggle('active', game.currentPlayer === 1);
    player2Info.classList.toggle('active', game.currentPlayer === 2);
}

function updateSkillButtons() {
    const currentPlayer = game.currentPlayer;
    
    document.querySelectorAll('.skill-btn').forEach(btn => {
        const skill = btn.dataset.skill;
        const player = parseInt(btn.dataset.player);
        
        // 检查是否是当前玩家的按钮
        if (player !== currentPlayer) {
            btn.disabled = true;
            return;
        }
        
        // 检查技能是否可用
        const cooldown = game.skillCooldowns[player][skill];
        const cooldownSpan = btn.querySelector('.cooldown');

        if (cooldown > 0) {
            btn.disabled = true;
            cooldownSpan.textContent = `冷却 ${cooldown} 回合`;
            cooldownSpan.style.background = '#ccc';
        } else {
            // 使用canUseSkill来检查技能是否可用（包括力拔山兮的特殊条件）
            const canUse = game.canUseSkill(skill);
            btn.disabled = game.gameOver || !canUse;
            cooldownSpan.textContent = canUse ? '可用' : '不可用';
            cooldownSpan.style.background = canUse ? '#4CAF50' : '#ccc';
        }
        
        // 检查技能激活状态
        if (game.skillMode === skill) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
}

function handleCellClick(e) {
    const cell = e.currentTarget;
    const row = parseInt(cell.dataset.row);
    const col = parseInt(cell.dataset.col);
    
    // 游戏结束时点击棋盘任意位置重新开始
    if (game.gameOver) {
        restartGame();
        return;
    }
    
    // 人机对战模式下，如果是AI回合，禁止玩家点击
    if (game.gameMode === 'pve' && game.currentPlayer === game.aiPlayer) {
        return;
    }
    
    // 处理技能模式
    if (game.skillMode === '飞沙走石') {
        const opponent = game.currentPlayer === 1 ? 2 : 1;
        if (game.board[row][col] === opponent) {
            if (game.skillFlyingSand(row, col)) {
                game.skillMode = null;
                updateBoard();
                updateStatus();
                updateSkillButtons();
                // AI回合处理
                if (game.gameMode === 'pve' && !game.gameOver && game.currentPlayer === game.aiPlayer) {
                    setTimeout(aiMove, 500);
                }
            }
        }
        return;
    }
    
    // 正常落子
    if (game.placePiece(row, col)) {
        updateBoard();
        updateStatus();
        updateSkillButtons();
        // AI回合处理
        if (game.gameMode === 'pve' && !game.gameOver && game.currentPlayer === game.aiPlayer) {
            setTimeout(aiMove, 500);
        }
    }
}

function handleSkillClick(e) {
    const btn = e.currentTarget;
    const skill = btn.dataset.skill;
    const player = parseInt(btn.dataset.player);
    
    if (game.gameOver || player !== game.currentPlayer) return;
    if (!game.canUseSkill(skill)) return;
    
    // 取消技能模式
    if (game.skillMode === skill) {
        game.skillMode = null;
        updateSkillButtons();
        return;
    }
    
    // 设置技能模式
    game.skillMode = skill;
    
    // 处理不同技能
    switch (skill) {
        case '飞沙走石':
            // 高亮对方棋子
            const opponent = game.currentPlayer === 1 ? 2 : 1;
            const cells = boardElement.querySelectorAll('.cell');
            cells.forEach(cell => {
                const row = parseInt(cell.dataset.row);
                const col = parseInt(cell.dataset.col);
                if (game.board[row][col] === opponent) {
                    cell.classList.add('skill-target');
                }
            });
            break;
            
        case '静如止水':
            game.skillStillWater();
            game.skillMode = null;
            updateStatus();
            updateSkillButtons();
            break;
            
        case '时光倒流':
            game.skillTimeReverse();
            game.skillMode = null;
            updateBoard();
            updateStatus();
            updateSkillButtons();
            break;
            
        case '力拔山兮':
            // 显示确认弹窗
            mountainPullModal.classList.add('show');
            break;
    }
    
    updateSkillButtons();
}

function restartGame() {
    game.reset();
    updateBoard();
    updateStatus();
    updateSkillButtons();
    // 显示模式选择弹窗
    modeSelectModal.classList.add('show');
}

// AI落子
function aiMove() {
    if (game.gameOver || game.currentPlayer !== game.aiPlayer) return;
    
    // 检查是否要跳过AI的回合
    if (game.skipNextTurn && game.skipPlayer === game.aiPlayer) {
        game.skipNextTurn = false;
        game.skipPlayer = null;
        game.switchPlayer();
        updateStatus();
        updateSkillButtons();
        return;
    }
    
    const move = game.getAIMove();
    if (move) {
        game.placePiece(move.row, move.col);
        updateBoard();
        updateStatus();
        updateSkillButtons();
    }
}

// 开始游戏（选择模式后）
function startGame(mode) {
    game.gameMode = mode;
    modeSelectModal.classList.remove('show');
    
    // 如果是人机模式，更新玩家信息显示
    if (mode === 'pve') {
        player2Info.querySelector('h3').textContent = '⚪ 白棋 (AI)';
    } else {
        player2Info.querySelector('h3').textContent = '⚪ 白棋 (玩家2)';
    }
    
    updateBoard();
    updateStatus();
    updateSkillButtons();
}

// 初始化游戏
initBoard();
updateBoard();
updateStatus();
updateSkillButtons();

// 显示模式选择弹窗
modeSelectModal.classList.add('show');

// 绑定事件
document.querySelectorAll('.skill-btn').forEach(btn => {
    btn.addEventListener('click', handleSkillClick);
});

restartBtn.addEventListener('click', () => {
    // 只有在游戏进行中时才显示确认弹窗
    if (!game.gameOver) {
        restartModal.classList.add('show');
    } else {
        // 游戏已结束，直接重新开始
        restartGame();
    }
});

// 弹窗控制
infoBtn.addEventListener('click', () => {
    infoModal.classList.add('show');
});

closeModal.addEventListener('click', () => {
    infoModal.classList.remove('show');
});

infoModal.addEventListener('click', (e) => {
    if (e.target === infoModal) {
        infoModal.classList.remove('show');
    }
});

// 重新开始确认弹窗控制
closeRestartModal.addEventListener('click', () => {
    restartModal.classList.remove('show');
});

cancelRestartBtn.addEventListener('click', () => {
    restartModal.classList.remove('show');
});

confirmRestartBtn.addEventListener('click', () => {
    restartModal.classList.remove('show');
    restartGame();
});

restartModal.addEventListener('click', (e) => {
    if (e.target === restartModal) {
        restartModal.classList.remove('show');
    }
});

// 力拔山兮确认弹窗控制
closeMountainPullModal.addEventListener('click', () => {
    mountainPullModal.classList.remove('show');
    game.skillMode = null;
    updateSkillButtons();
});

cancelMountainPullBtn.addEventListener('click', () => {
    mountainPullModal.classList.remove('show');
    game.skillMode = null;
    updateSkillButtons();
});

confirmMountainPullBtn.addEventListener('click', () => {
    mountainPullModal.classList.remove('show');
    game.skillMode = null;
    
    // 执行力拔山兮炸飞特效
    playMountainPullEffect();
});

function playMountainPullEffect() {
    const board = document.getElementById('board');
    const pieces = document.querySelectorAll('.piece');
    
    // 1. 震动棋盘
    board.classList.add('shaking');
    
    // 2. 炸飞所有棋子
    setTimeout(() => {
        pieces.forEach(piece => {
            // 为每个棋子生成随机的飞出方向
            const angle = Math.random() * Math.PI * 2;
            const distance = 100 + Math.random() * 100;
            const dx = Math.cos(angle) * distance;
            const dy = Math.sin(angle) * distance;
            
            piece.style.setProperty('--dx', `${dx}px`);
            piece.style.setProperty('--dy', `${dy}px`);
            piece.classList.add('exploding');
        });
    }, 300);
    
    // 3. 恢复棋盘并显示获胜
    setTimeout(() => {
        board.classList.remove('shaking');
        board.classList.add('resetting');
        
        // 执行力拔山兮技能
        game.skillMountainPull();
        // 设置力拔山兮为已使用
        game.skillCooldowns[game.currentPlayer]['力拔山兮'] = -1;
        
        // 清空棋盘上所有棋子
        const cells = boardElement.querySelectorAll('.cell');
        cells.forEach(cell => {
            cell.innerHTML = '';
            // 添加hover指示器
            const hoverIndicator = document.createElement('div');
            hoverIndicator.className = 'hover-indicator';
            cell.appendChild(hoverIndicator);
        });
        
        updateStatus();
        updateSkillButtons();
        
        setTimeout(() => {
            board.classList.remove('resetting');
        }, 500);
    }, 1200);
}

mountainPullModal.addEventListener('click', (e) => {
    if (e.target === mountainPullModal) {
        mountainPullModal.classList.remove('show');
        game.skillMode = null;
        updateSkillButtons();
    }
});

// 模式选择弹窗控制
closeModeSelectModal.addEventListener('click', () => {
    modeSelectModal.classList.remove('show');
});

pvpBtn.addEventListener('click', () => {
    startGame('pvp');
});

pveBtn.addEventListener('click', () => {
    startGame('pve');
});

modeSelectModal.addEventListener('click', (e) => {
    if (e.target === modeSelectModal) {
        modeSelectModal.classList.remove('show');
    }
});