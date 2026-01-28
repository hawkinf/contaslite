/**
 * Script para enviar email de teste com dados reais
 * Uso: node scripts/send_test_report.js
 */
const { User } = require('../src/models');
const schedulerService = require('../src/services/schedulerService');
const emailService = require('../src/services/emailService');

const targetEmail = process.argv[2] || 'hawkinf@gmail.com';
const frequency = process.argv[3] || 'monthly'; // daily, weekly, biweekly, monthly

(async () => {
  try {
    console.log('Inicializando serviço de email...');
    emailService.initialize();

    if (!emailService.isConfigured()) {
      console.error('Serviço de email não configurado!');
      process.exit(1);
    }

    // Busca o usuário pelo email
    console.log(`Buscando usuário: ${targetEmail}`);
    const user = await User.findOne({ where: { email: targetEmail } });
    if (!user) {
      console.error('Usuário não encontrado');
      process.exit(1);
    }

    console.log(`Usuário encontrado: ID=${user.id}, Nome=${user.name}`);

    // Gera dados do relatório
    console.log(`Gerando dados do relatório (frequência: ${frequency})...`);
    const reportData = await schedulerService.generateReportData(user.id, frequency, new Date());

    console.log('\n=== DADOS DO RELATÓRIO ===');
    console.log(`Usuário: ${reportData.userName}`);
    console.log(`Data: ${reportData.date}`);
    console.log(`Contas a Pagar: ${reportData.contasPagar.length}`);
    console.log(`Contas a Receber: ${reportData.contasReceber.length}`);
    console.log(`Total a Pagar: R$ ${reportData.totalPagar.toFixed(2)}`);
    console.log(`Total a Receber: R$ ${reportData.totalReceber.toFixed(2)}`);

    if (reportData.contasPagar.length > 0) {
      console.log('\nContas a Pagar:');
      reportData.contasPagar.forEach((c, i) => {
        console.log(`  ${i+1}. ${c.description} - R$ ${c.value.toFixed(2)} - ${c.isPaid ? 'PAGO' : 'PENDENTE'}`);
      });
    }

    if (reportData.contasReceber.length > 0) {
      console.log('\nContas a Receber:');
      reportData.contasReceber.forEach((c, i) => {
        console.log(`  ${i+1}. ${c.description} - R$ ${c.value.toFixed(2)} - ${c.isPaid ? 'RECEBIDO' : 'PENDENTE'}`);
      });
    }

    // Gera HTML e envia
    console.log('\nGerando HTML e enviando email...');
    const html = emailService.generateAccountsReportHtml(reportData);
    await emailService.sendEmail(user.email, '📊 Relatório de Contas - Teste Manual', html);

    console.log(`\n✅ Email enviado com sucesso para ${user.email}!`);
    process.exit(0);
  } catch (e) {
    console.error('Erro:', e);
    process.exit(1);
  }
})();
