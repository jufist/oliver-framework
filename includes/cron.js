var c = {};
c.channels = {};

c.cronExecute = function(channel, cronid, callbackfinal) {
	if (c.channels[channel]) {
		cl(`[Cron] [${cronid}] [Error] Cron is overlappeda at channel ${channel}. Will try next time!`);
		return ;
	}
	cl(`[Cron] [${cronid}] Cron ${cronid} starts executing`)
	c.lock(channel);
	callbackfinal().then(function() {
		cl(`[Cron] [${cronid}] Cron ${cronid} executed`)
		c.unlock(channel);
	});
}

c.unlock = function(channel) {
	delete c.channels[channel];
}

c.lock = function(channel) {
	c.channels[channel] = 1;
}

c.init = function(menus) {
	var cron = require('node-cron');
	
	var solveMenus = function(toSolveMenus) {
		Object.keys(toSolveMenus).forEach(function(menu) {
			if (toSolveMenus[menu]['cron']) {
				var channel = toSolveMenus[menu]['channel'] || "global";
				cron.schedule(toSolveMenus[menu]['cron'], nodeproxy(function() {
						c.cronExecute(this.channel, menu, toSolveMenus[menu]['callbackfinal']);
					},  {channel:channel}));		
			}
			if (toSolveMenus[menu]['children']) {
				solveMenus(toSolveMenus[menu]['children']);
			}
		});
	}
	solveMenus(menus);
}

module.exports = c;