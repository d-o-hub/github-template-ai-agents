const { ignores, rules } = require('./commitlint.config.cjs');
const message = `perf: eliminate subshells in validate-skills loop\n\nWhat: Replaced awk, grep, and python3 subprocess forks with native Bash parameter expansion, regex, and jq inside the validate-skills.sh loop.\nWhy: Spawning new processes inside high-frequency bash loops creates significant execution overhead.\nImpact: Reduces script execution time by ~15x (from ~17s to ~1.5s).\nMeasurement: Run time ./scripts/validate-skills.sh to verify execution speed.`;

console.log("Ignore dependabot:", ignores[0](message));
console.log("Ignore bot emoji:", ignores[1](message));
console.log("Ignore bot coauthor:", ignores[2](message));

const core = require('@commitlint/core');
const load = require('@commitlint/load');
const lint = require('@commitlint/lint');

async function test() {
    const config = await load({extends: ['@commitlint/config-conventional']});
    const result = await lint(message, config.rules, { parserOpts: config.parserPreset.parserOpts });
    console.log(result);
}

test();
