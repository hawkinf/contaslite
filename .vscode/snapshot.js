#!/usr/bin/env node

/**
 * Project Snapshot Tool
 * Cria snapshots (backups) do projeto a cada 30 minutos
 * Mantém apenas os últimos 10 snapshots
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const SNAPSHOT_INTERVAL = 30 * 60 * 1000; // 30 minutos em millisegundos
const MAX_SNAPSHOTS = 10;
const SNAPSHOTS_DIR = path.join(__dirname, '..', '.snapshots');

/**
 * Cria diretório de snapshots se não existir
 */
function ensureSnapshotsDir() {
  if (!fs.existsSync(SNAPSHOTS_DIR)) {
    fs.mkdirSync(SNAPSHOTS_DIR, { recursive: true });
    console.log(`📁 Diretório de snapshots criado: ${SNAPSHOTS_DIR}`);
  }
}

/**
 * Gera timestamp formatado
 */
function getTimestamp() {
  const now = new Date();
  return now.toISOString().replace(/[:.]/g, '-').slice(0, -5);
}

/**
 * Cria um snapshot do projeto
 */
function createSnapshot() {
  try {
    const timestamp = getTimestamp();
    const snapshotName = `snapshot-${timestamp}`;
    const snapshotPath = path.join(SNAPSHOTS_DIR, snapshotName);

    console.log(`\n📸 Criando snapshot: ${snapshotName}`);
    console.log(`⏰ Horário: ${new Date().toLocaleString('pt-BR')}`);

    // Criar diretório do snapshot
    fs.mkdirSync(snapshotPath, { recursive: true });

    // Copiar arquivos importantes (ignorando node_modules, build, etc)
    const projectRoot = path.join(__dirname, '..');
    const excludeDirs = [
      'node_modules',
      'build',
      '.dart_tool',
      'dist',
      '.git',
      '.idea',
      '.vscode',
      '.snapshots'
    ];

    copyFilesRecursive(projectRoot, snapshotPath, excludeDirs);

    // Criar arquivo de metadados
    const metadata = {
      timestamp: new Date().toISOString(),
      name: snapshotName,
      size: getDirectorySize(snapshotPath),
      files: countFiles(snapshotPath)
    };

    fs.writeFileSync(
      path.join(snapshotPath, '.snapshot.json'),
      JSON.stringify(metadata, null, 2)
    );

    console.log(`✅ Snapshot criado com sucesso!`);
    console.log(`   Nome: ${snapshotName}`);
    console.log(`   Tamanho: ${formatSize(metadata.size)}`);
    console.log(`   Arquivos: ${metadata.files}`);

    // Limpar snapshots antigos
    rotateSnapshots();

  } catch (error) {
    console.error(`❌ Erro ao criar snapshot: ${error.message}`);
  }
}

/**
 * Copia arquivos recursivamente, ignorando diretórios específicos
 */
function copyFilesRecursive(source, destination, excludeDirs) {
  const items = fs.readdirSync(source);

  items.forEach(item => {
    // Ignorar arquivos e diretórios da lista
    if (excludeDirs.includes(item) || item.startsWith('.')) {
      return;
    }

    const sourcePath = path.join(source, item);
    const destPath = path.join(destination, item);
    const stat = fs.statSync(sourcePath);

    if (stat.isDirectory()) {
      fs.mkdirSync(destPath, { recursive: true });
      copyFilesRecursive(sourcePath, destPath, excludeDirs);
    } else {
      // Copiar arquivo
      fs.copyFileSync(sourcePath, destPath);
    }
  });
}

/**
 * Conta arquivos em um diretório recursivamente
 */
function countFiles(dir) {
  let count = 0;
  const items = fs.readdirSync(dir);

  items.forEach(item => {
    const itemPath = path.join(dir, item);
    const stat = fs.statSync(itemPath);

    if (stat.isDirectory()) {
      count += countFiles(itemPath);
    } else {
      count++;
    }
  });

  return count;
}

/**
 * Calcula tamanho de um diretório recursivamente
 */
function getDirectorySize(dir) {
  let size = 0;
  const items = fs.readdirSync(dir);

  items.forEach(item => {
    const itemPath = path.join(dir, item);
    const stat = fs.statSync(itemPath);

    if (stat.isDirectory()) {
      size += getDirectorySize(itemPath);
    } else {
      size += stat.size;
    }
  });

  return size;
}

/**
 * Formata tamanho em bytes para formato legível
 */
function formatSize(bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  let size = bytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return `${size.toFixed(2)} ${units[unitIndex]}`;
}

/**
 * Lista todos os snapshots ordenados por data
 */
function listSnapshots() {
  if (!fs.existsSync(SNAPSHOTS_DIR)) {
    return [];
  }

  const snapshots = fs.readdirSync(SNAPSHOTS_DIR)
    .filter(name => name.startsWith('snapshot-'))
    .map(name => {
      const snapshotPath = path.join(SNAPSHOTS_DIR, name);
      const stat = fs.statSync(snapshotPath);
      return { name, mtime: stat.mtime };
    })
    .sort((a, b) => b.mtime - a.mtime);

  return snapshots;
}

/**
 * Remove snapshots antigos, mantendo apenas MAX_SNAPSHOTS
 */
function rotateSnapshots() {
  const snapshots = listSnapshots();

  if (snapshots.length > MAX_SNAPSHOTS) {
    console.log(`\n🗑️  Limpando snapshots antigos (mantendo ${MAX_SNAPSHOTS})...`);

    const toDelete = snapshots.slice(MAX_SNAPSHOTS);
    toDelete.forEach(snapshot => {
      try {
        const snapshotPath = path.join(SNAPSHOTS_DIR, snapshot.name);
        console.log(`   ❌ Removendo: ${snapshot.name}`);
        removeDirectoryRecursive(snapshotPath);
      } catch (error) {
        console.error(`   ⚠️  Erro ao remover ${snapshot.name}: ${error.message}`);
      }
    });
  }
}

/**
 * Remove diretório recursivamente
 */
function removeDirectoryRecursive(dir) {
  if (fs.existsSync(dir)) {
    fs.readdirSync(dir).forEach(file => {
      const filePath = path.join(dir, file);
      if (fs.lstatSync(filePath).isDirectory()) {
        removeDirectoryRecursive(filePath);
      } else {
        fs.unlinkSync(filePath);
      }
    });
    fs.rmdirSync(dir);
  }
}

/**
 * Inicia o serviço de snapshots periódicos
 */
function startSnapshotService() {
  console.log(`
╔════════════════════════════════════════════════════════╗
║        🎥 Project Snapshot Service Iniciado            ║
║    Snapshots a cada 30 minutos | Máx: ${MAX_SNAPSHOTS} snapshots    ║
╚════════════════════════════════════════════════════════╝
  `);

  ensureSnapshotsDir();

  // Criar primeiro snapshot imediatamente
  createSnapshot();

  // Criar snapshot a cada 30 minutos
  setInterval(() => {
    createSnapshot();
  }, SNAPSHOT_INTERVAL);

  console.log(`\n⏰ Próximo snapshot em: 30 minutos`);
  console.log(`📁 Diretório: ${SNAPSHOTS_DIR}\n`);

  // Manter o processo rodando
  process.on('SIGINT', () => {
    console.log('\n\n👋 Serviço de snapshots encerrado.');
    process.exit(0);
  });
}

/**
 * Mode: list - Lista todos os snapshots
 */
if (process.argv[2] === 'list') {
  ensureSnapshotsDir();
  const snapshots = listSnapshots();

  if (snapshots.length === 0) {
    console.log('Nenhum snapshot encontrado.');
  } else {
    console.log(`\n📸 Snapshots encontrados (${snapshots.length}/${MAX_SNAPSHOTS}):\n`);
    snapshots.forEach((snapshot, index) => {
      const snapshotPath = path.join(SNAPSHOTS_DIR, snapshot.name);
      const metadata = JSON.parse(
        fs.readFileSync(path.join(snapshotPath, '.snapshot.json'), 'utf-8')
      );
      console.log(`${index + 1}. ${snapshot.name}`);
      console.log(`   Data: ${new Date(metadata.timestamp).toLocaleString('pt-BR')}`);
      console.log(`   Tamanho: ${formatSize(metadata.size)}`);
      console.log(`   Arquivos: ${metadata.files}\n`);
    });
  }
  process.exit(0);
}

/**
 * Mode: cleanup - Limpa snapshots antigos
 */
if (process.argv[2] === 'cleanup') {
  ensureSnapshotsDir();
  rotateSnapshots();
  console.log('✅ Limpeza concluída.');
  process.exit(0);
}

// Modo padrão: inicia o serviço
startSnapshotService();
