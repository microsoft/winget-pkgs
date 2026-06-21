import { execSync } from 'child_process';

const version = '12.19.0.7314';
const releaseNotesUrl = 'https://github.com/HeidiSQL/HeidiSQL/releases/tag/v12.19.0.7314';
const downloadUrl = 'https://github.com/HeidiSQL/HeidiSQL/releases/download/v12.19/HeidiSQL_12.19.0.7314_Setup.exe';

console.log(`Updating HeidiSQL to version ${version}`);
console.log(`Release notes: ${releaseNotesUrl}`);
console.log(`Download: ${downloadUrl}`);

// Simulate download and install
execSync(`curl -L ${downloadUrl} -o heidisql_setup.exe`);
execSync('start heidisql_setup.exe', { shell: 'cmd' });