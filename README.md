# backups-unstoppable

Reproduction:

1. Docker running
2. git clone and switch to branch "rustic-testing-issue"
3. Set .env file in project root with content: `PASSWORD=F217BDD74ACC44253C416BE444BC4E6C8D0942C46B422E60C02F46B1342E6708`
4. Decrypt env variables: `./locker.sh unlock`
5. Run docker containers: `./manual-mode.sh`
6. Wait a moment, until the shell in the rustic container opens!
7. Run `/rustic init`
