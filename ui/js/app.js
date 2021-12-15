// Salam Be Roye Mahet :) Khoobi?
const main = document.getElementById("xpm_main");
const container = document.querySelector(".xpm");
const inner = document.querySelector(".xpm-inner");
const [ rankA, rankB ] = [...container.querySelectorAll(".xpm-rank")];
const xpBar = container.querySelector(".xpm-progress");
const barA = container.querySelector(".xpm-indicator--bar");
const bar = container.querySelector(".xpm-progress--bar");
const counter = container.querySelector(".xpm-data");

let globalConfig = false;
let displayTimer = false;
let interval = 5000;
let initialised = false;
let segments = 10;
let rankbar = false;
let leaderboard = false;
let currentID = false;

function renderBar() {
    const frag = document.createDocumentFragment();
    for (let i = 0; i < segments; i++) {
        const div = document.createElement("div");
        div.classList.add("xpm-segment");
        div.innerHTML = `<div class="xpmm-indicator--bar"></div><div class="xpm-progress--bar"></div>`;

        frag.appendChild(div);
    }

    xpBar.appendChild(frag);
}

function fillSegments(pr, child) {
    const p = (segments / 100) * pr;
    const filled = Math.floor(p);
    const partial = p % 1;

    for (let i = 0; i < segments; i++) {
        if (i + 1 <= filled) {
            xpBar.children[i][child].style.width = "100%";
        } else {
            xpBar.children[i][child].style.width = "0%";
        }

        if (i + 1 === filled + 1) {
            xpBar.children[i][child].style.width = `${partial * 100}%`;
        }
    }
}

function TriggerRankChange(rankUp, current, previous) {
    if ( leaderboard && currentID ) {
        leaderboard.updateRank(currentID, current);
    }

    fetch(`https://${GetParentResourceName()}/behnam_rankchange`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ rankUp, current, previous })
    });
}

function UIOpen() {
    main.classList.add("active");
    window.clearTimeout(displayTimer);
}

function UITimeout() {
    UIOpen();

    displayTimer = window.setTimeout(() => {
        UIClose();
    }, globalConfig.Timeout);
}

function UIClose() {
    window.clearTimeout(displayTimer);
    displayTimer = false;

    main.classList.remove("active");

    PostData("uichange");
}

function PostData(type = "", data = {}) {
    fetch(`http://${GetParentResourceName()}/xpm_${type}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data)
    })//.then(resp => resp.json()).then(resp => resp).catch(error => console.log('BR_XP FETCH ERROR! ' + error.message));    
}

window.onData = function (data) {
    
    if (data.xpm_init && !initialised) {

        globalConfig = data.xpm_config

        if ( data.currentID !== false ) {
            currentID = data.currentID
        }

        if ( data.leaderboard ) {
            leaderboard = new Leaderboard({
                showPing: globalConfig.Leaderboard.ShowPing,
                perPage: globalConfig.Leaderboard.PerPage,
                sortBy: globalConfig.Leaderboard.Order
            });

            leaderboard.render();

            if ( data.players.length > 0 ) {
                leaderboard.addPlayers(data.players);
            }
        }

        const ranks = {};

        for ( let i = 0; i < data.xpm_config.Ranks.length; i++ ) {
            ranks[i+1] = data.xpm_config.Ranks[i];
        }

        rankbar = new XPM({
            xp: data.xp,
            ranks: ranks,

            onInit: function (progress) {

                segments = data.xpm_config.BarSegments

                renderBar();

                inner.style.width = `${data.xpm_config.Width}px`;

                UITimeout();             

                fillSegments(progress, "lastElementChild");

                rankA.firstElementChild.textContent = this.currentRank;
                rankB.firstElementChild.textContent = this.nextRank;
		
                counter.children[0].textContent = this.currentXP;
                counter.children[1].textContent = this.config.ranks[this.nextRank];

                rankA.classList.add(`xp-rank-${this.currentRank}`);
                rankB.classList.add(`xp-rank-${this.nextRank}`);                   

                initialised = true;
            },
	
            onStart: function(add) {
                UIOpen();

                xpBar.classList.toggle("xpm-remove", !add);
            },

            onChange: function (progress, xp, max, add) {
                main.classList.add("active");
                
                fillSegments(progress, "lastElementChild");
		
                fillSegments(max, "firstElementChild");

                counter.children[0].textContent = xp;
            },

            onRankChange: function (current, next, previous, add, max, rankUp) {

                // Fire rank change to update client UI
                TriggerRankChange(rankUp, current, previous)

                // Remove old ranks
                rankA.classList.remove(`xp-rank-${previous}`);
                rankB.classList.remove(`xp-rank-${current}`);
                rankB.classList.remove(`xpm-rank-${previous + 1}`);              
        
                // add new ranks
                rankA.classList.add(`xp-rank-${current}`);
                rankB.classList.add(`xp-rank-${next}`);                     

                counter.children[1].textContent = this.config.ranks[next];
		
                rankB.classList.add("pulse");
		
                fillSegments(0, "firstElementChild");
		
                setTimeout(() => {
                    rankB.classList.remove("pulse");
                    rankA.classList.add("spin");
                    rankA.classList.add("highlight");
                    rankB.classList.add("spin");
			
                    rankA.firstElementChild.textContent = current;
                    rankB.firstElementChild.textContent = next;		
			
                    setTimeout(() => {
                        rankA.classList.remove("spin");
                        rankA.classList.remove("highlight");
                        rankB.classList.remove("spin");
                        rankB.classList.remove("highlight");
                    }, 250);			
                }, 250);				
            },
	
            onEnd: function (add) {
                UITimeout();

                xpBar.classList.remove("xpm-remove");
            }
        });
    }

    if ( initialised ) {
        if (data.xpm_set) {
            rankbar.setXP(data.xp);
        }

        if (data.xpm_add) {
            rankbar.addXP(data.xp);
        }

        if (data.xpm_remove) {
            rankbar.removeXP(data.xp);
        }    
    
        if (data.xpm_display) {
            UITimeout();
        }   

        if (data.xpm_show) {
            UITimeout();
        } else if (data.xpm_hide) {
            UIClose();
        }

        if ( leaderboard ) {
            if ( data.xpm_lb_prev ) {
                UITimeout();
                leaderboard.prevPage();
            }

            if ( data.xpm_lb_next ) {
                UITimeout();
                leaderboard.nextPage();
            }  
            
            if ( data.xpm_lb_sort ) {
                leaderboard.config.sortBy = data.xpm_lb_order;
                leaderboard.update();
            }

            if (data.xpm_updateleaderboard) {
                leaderboard.updatePlayers(data.xpm_players);
            }
        }
    }    
};

window.onload = function (e) {
    window.addEventListener('message', function (e) {
        onData(e.data);
    });
};