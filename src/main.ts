import { execSync } from 'child_process';

const currentVersion = '12.19.0.7314';

function updatePackageJson() {
  try {
    const packageJson = JSON.parse(
      execSync('cat package.json', { encoding: 'utf-8' })
    );

    if (packageJson.name === 'HeidiSQL.HeidiSQL') {
      packageJson.version = currentVersion;
      const updated = JSON.stringify(packageJson, null, 2);
      execSync('echo "' + updated + '" > package.json', { stdio: 'replace' });
      console.log('✅ Updated package.json version to', currentVersion);
    } else {
      console.log('❌ package.json does not have the correct name');
    }
  } catch (error) {
    console.log('❌ Error updating package.json:', error);
  }
}

function updateReadme() {
  try {
    const readme = execSync('cat README.md', { encoding: 'utf-8' });
    const updated = readme
      .replace(
        /## HeidiSQL\s*-\s*\S*\s*\(\S*\)/,
        `## HeidiSQL - ${currentVersion} (${new Date().toISOString().slice(0, 10)})`
      );
    execSync('echo "' + updated + '" > README.md', { stdio: 'replace' });
    console.log('✅ Updated README.md with new version');
  } catch (error) {
    console.log('❌ Error updating README.md:', error);
  }
}

updatePackageJson();
updateReadme();