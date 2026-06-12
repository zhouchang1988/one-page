class GomokuGame {
    constructor() {
        this.boardSize = 15;
        this.board = [];
        this.currentPlayer = 1; // 1: 黑棋, 2: 白棋
        this.gameOver = false;
        this.history = []; // 记录每一步的历史，用于时光倒流
        this.skillCooldowns = {
            1: { '飞沙走石': 0, '静如止水': 0, '时光倒流': 0, '力拔山兮': 1 },
            2: { '飞沙走石': 0, '静如止水': 0, '时光倒流': 0, '力拔山兮': 1 }
        };
        this.skipNextTurn = false; // 是否跳过下一回合
        this.skipPlayer = null; // 要跳过的玩家
        this.skillMode = null; // 当前技能模式
        this.gameMode = 'pvp'; // 'pvp': 双人对战, 'pve': 人机对战
        this.aiPlayer = 2; // AI控制的玩家（默认白棋）
        this.initBoard();
    }

    initBoard() {
        this.board = Array(this.boardSize).fill(null).map(() => Array(this.boardSize).fill(0));
    }

    placePiece(row, col) {
        if (this.gameOver || this.board[row][col] !== 0) return false;

        // 检查是否要跳过当前玩家的回合
        if (this.skipNextTurn && this.skipPlayer === this.currentPlayer) {
            this.skipNextTurn = false;
            this.skipPlayer = null;
            this.switchPlayer();
            return true;
        }

        // 保存当前状态到历史
        this.saveHistory();

        this.board[row][col] = this.currentPlayer;
        
        // 检查胜利
        if (this.checkWin(row, col)) {
            this.gameOver = true;
            return true;
        }

        this.switchPlayer();
        return true;
    }

    switchPlayer() {
        this.currentPlayer = this.currentPlayer === 1 ? 2 : 1;
        // 减少技能冷却
        for (let skill in this.skillCooldowns[this.currentPlayer]) {
            if (this.skillCooldowns[this.currentPlayer][skill] > 0) {
                this.skillCooldowns[this.currentPlayer][skill]--;
            }
        }
    }

    checkWin(row, col) {
        const directions = [
            [[0, 1], [0, -1]], // 水平
            [[1, 0], [-1, 0]], // 垂直
            [[1, 1], [-1, -1]], // 对角线
            [[1, -1], [-1, 1]]  // 反对角线
        ];

        const player = this.board[row][col];

        for (let direction of directions) {
            let count = 1;
            for (let dir of direction) {
                let r = row + dir[0];
                let c = col + dir[1];
                while (r >= 0 && r < this.boardSize && c >= 0 && c < this.boardSize && 
                       this.board[r][c] === player) {
                    count++;
                    r += dir[0];
                    c += dir[1];
                }
            }
            if (count >= 5) return true;
        }
        return false;
    }

    saveHistory() {
        this.history.push({
            board: JSON.parse(JSON.stringify(this.board)),
            currentPlayer: this.currentPlayer,
            skillCooldowns: JSON.parse(JSON.stringify(this.skillCooldowns))
        });
    }

    // 技能1: 飞沙走石 - 移除对方一个棋子
    skillFlyingSand(row, col) {
        const opponent = this.currentPlayer === 1 ? 2 : 1;
        if (this.board[row][col] !== opponent) return false;
        
        this.saveHistory();
        this.board[row][col] = 0;
        this.skillCooldowns[this.currentPlayer]['飞沙走石'] = 3; // 冷却3回合
        return true;
    }

    // 技能2: 静如止水 - 让对方暂停一回合
    skillStillWater() {
        this.saveHistory();
        const opponent = this.currentPlayer === 1 ? 2 : 1;
        this.skipNextTurn = true;
        this.skipPlayer = opponent; // 记录要跳过的是对方
        this.skillCooldowns[this.currentPlayer]['静如止水'] = 3; // 冷却3回合
        return true;
    }

    // 技能3: 时光倒流 - 退回到上一回合
    skillTimeReverse() {
        if (this.history.length === 0) return false;
        
        const lastState = this.history.pop();
        this.board = lastState.board;
        this.currentPlayer = lastState.currentPlayer;
        this.skillCooldowns = lastState.skillCooldowns;
        this.skillCooldowns[this.currentPlayer]['时光倒流'] = 3; // 冷却3回合
        return true;
    }

    // 技能4: 力拔山兮 - 直接获胜（只能使用一次）
    skillMountainPull() {
        if (this.skillCooldowns[this.currentPlayer]['力拔山兮'] === -1) return false;

        this.gameOver = true;
        return true;
    }

    canUseSkill(skillName) {
        if (skillName === '力拔山兮') {
            // 力拔山兮需要双方都下了一枚棋子后才可用（历史记录至少有2条）
            return this.skillCooldowns[this.currentPlayer][skillName] === 0 && this.history.length >= 2;
        }
        return this.skillCooldowns[this.currentPlayer][skillName] === 0;
    }

    reset() {
        this.initBoard();
        this.currentPlayer = 1;
        this.gameOver = false;
        this.history = [];
        this.skillCooldowns = {
            1: { '飞沙走石': 0, '静如止水': 0, '时光倒流': 0, '力拔山兮': 1 },
            2: { '飞沙走石': 0, '静如止水': 0, '时光倒流': 0, '力拔山兮': 1 }
        };
        this.skipNextTurn = false;
        this.skipPlayer = null;
        this.skillMode = null;
    }

    // AI获取最佳落子位置
    getAIMove() {
        let bestScore = -Infinity;
        let bestMove = null;
        
        // 获取所有空位
        const emptyCells = [];
        for (let row = 0; row < this.boardSize; row++) {
            for (let col = 0; col < this.boardSize; col++) {
                if (this.board[row][col] === 0) {
                    // 只考虑有邻居的位置（优化性能）
                    if (this.hasNeighbor(row, col)) {
                        emptyCells.push({ row, col });
                    }
                }
            }
        }
        
        // 如果棋盘为空，下在中心
        if (emptyCells.length === 0) {
            return { row: 7, col: 7 };
        }
        
        // 评估每个位置
        for (const cell of emptyCells) {
            const score = this.evaluatePosition(cell.row, cell.col);
            if (score > bestScore) {
                bestScore = score;
                bestMove = cell;
            }
        }
        
        return bestMove;
    }

    // 检查位置周围是否有棋子
    hasNeighbor(row, col) {
        const range = 2;
        for (let dr = -range; dr <= range; dr++) {
            for (let dc = -range; dc <= range; dc++) {
                if (dr === 0 && dc === 0) continue;
                const nr = row + dr;
                const nc = col + dc;
                if (nr >= 0 && nr < this.boardSize && nc >= 0 && nc < this.boardSize) {
                    if (this.board[nr][nc] !== 0) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    // 评估某个位置的分数
    evaluatePosition(row, col) {
        const aiPlayer = this.aiPlayer;
        const humanPlayer = aiPlayer === 1 ? 2 : 1;
        
        // 评估AI落子后的分数（进攻）
        this.board[row][col] = aiPlayer;
        const attackScore = this.evaluatePositionScore(row, col, aiPlayer);
        this.board[row][col] = 0;
        
        // 评估对手落子后的分数（防守）
        this.board[row][col] = humanPlayer;
        const defenseScore = this.evaluatePositionScore(row, col, humanPlayer);
        this.board[row][col] = 0;
        
        // 综合评分，防守略重要
        return attackScore + defenseScore * 1.1;
    }

    // 评估某个位置对某个玩家的价值
    evaluatePositionScore(row, col, player) {
        const directions = [
            [[0, 1], [0, -1]], // 水平
            [[1, 0], [-1, 0]], // 垂直
            [[1, 1], [-1, -1]], // 对角线
            [[1, -1], [-1, 1]]  // 反对角线
        ];
        
        let totalScore = 0;
        
        for (const direction of directions) {
            const score = this.evaluateDirection(row, col, direction, player);
            totalScore += score;
        }
        
        return totalScore;
    }

    // 评估某个方向上的分数
    evaluateDirection(row, col, direction, player) {
        let count = 1; // 包含当前落子
        let blocked = 0;
        let empty = 0;
        
        // 检查两个方向
        for (const dir of direction) {
            let r = row + dir[0];
            let c = col + dir[1];
            let consecutive = 0;
            
            while (r >= 0 && r < this.boardSize && c >= 0 && c < this.boardSize) {
                if (this.board[r][c] === player) {
                    consecutive++;
                    count++;
                } else if (this.board[r][c] === 0) {
                    empty++;
                    break;
                } else {
                    blocked++;
                    break;
                }
                r += dir[0];
                c += dir[1];
            }
        }
        
        // 根据连子数、空位数、被阻挡数评分
        if (count >= 5) return 100000; // 必胜
        if (count === 4 && blocked === 0) return 10000; // 活四
        if (count === 4 && blocked === 1) return 1000; // 冲四
        if (count === 3 && blocked === 0) return 1000; // 活三
        if (count === 3 && blocked === 1) return 100; // 眠三
        if (count === 2 && blocked === 0) return 100; // 活二
        if (count === 2 && blocked === 1) return 10; // 眠二
        if (count === 1 && empty >= 1) return 1; // 单子
        
        return 0;
    }
}