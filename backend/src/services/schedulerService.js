/**
 * Serviço de Agendamento - Gerencia jobs de envio de email
 */
const cron = require('node-cron');
const { Op } = require('sequelize');
const { User, Account, AccountType, EmailSchedule, Payment } = require('../models');
const emailService = require('./emailService');
const logger = require('../utils/logger');

class SchedulerService {
  constructor() {
    this.jobs = new Map();
    this.initialized = false;
  }

  /**
   * Inicializa o serviço de agendamento
   */
  initialize() {
    if (this.initialized) return;

    // Inicializa o serviço de email
    emailService.initialize();

    // Executa verificação a cada minuto
    cron.schedule('* * * * *', () => {
      this.checkAndSendEmails();
    });

    this.initialized = true;
    logger.info('Scheduler service initialized - checking emails every minute');
  }

  /**
   * Verifica e envia emails pendentes
   */
  async checkAndSendEmails() {
    if (!emailService.isConfigured()) {
      return;
    }

    try {
      const now = new Date();
      const currentHour = now.getHours();
      const currentMinute = now.getMinutes();

      // Busca todos os schedules ativos que precisam ser enviados agora
      const schedules = await EmailSchedule.findAll({
        where: {
          is_enabled: true,
          send_hour: currentHour,
          send_minute: currentMinute
        },
        include: [{
          model: User,
          as: 'user',
          where: { is_active: true }
        }]
      });

      for (const schedule of schedules) {
        await this.processSchedule(schedule, now);
      }
    } catch (error) {
      logger.error('Error checking email schedules:', error);
    }
  }

  /**
   * Processa um schedule individual
   */
  async processSchedule(schedule, now) {
    try {
      // Verifica se já foi enviado hoje (para evitar duplicatas)
      if (schedule.last_sent_at) {
        const lastSent = new Date(schedule.last_sent_at);
        if (this.isSameDay(lastSent, now)) {
          return;
        }
      }

      // Verifica se é o dia correto baseado na frequência
      if (!this.shouldSendToday(schedule, now)) {
        return;
      }

      const user = schedule.user;
      const reportData = await this.generateReportData(user.id, schedule.frequency, now);

      // Gera o HTML do email
      const html = emailService.generateAccountsReportHtml(reportData);

      // Define o assunto baseado na frequência
      const subjectMap = {
        daily: 'Relatório Diário de Contas',
        weekly: 'Relatório Semanal de Contas',
        biweekly: 'Relatório Quinzenal de Contas',
        monthly: 'Relatório Mensal de Contas'
      };
      const subject = `📊 ${subjectMap[schedule.frequency]} - ${this.formatDate(now)}`;

      // Envia o email
      await emailService.sendEmail(user.email, subject, html);

      // Atualiza o schedule
      schedule.last_sent_at = now;
      schedule.next_send_at = this.calculateNextSend(schedule, now);
      await schedule.save();

      logger.info(`Email report sent to ${user.email}`);
    } catch (error) {
      logger.error(`Error processing schedule for user ${schedule.user_id}:`, error);
    }
  }

  /**
   * Verifica se deve enviar hoje baseado na frequência
   */
  shouldSendToday(schedule, now) {
    const dayOfWeek = now.getDay();
    const dayOfMonth = now.getDate();

    switch (schedule.frequency) {
      case 'daily':
        return true;

      case 'weekly':
        return dayOfWeek === schedule.weekly_day;

      case 'biweekly':
        // Envia na primeira e terceira semana do mês
        const weekOfMonth = Math.ceil(dayOfMonth / 7);
        return dayOfWeek === schedule.weekly_day && (weekOfMonth === 1 || weekOfMonth === 3);

      case 'monthly':
        return dayOfMonth === schedule.monthly_day;

      default:
        return false;
    }
  }

  /**
   * Calcula a próxima data de envio
   */
  calculateNextSend(schedule, from) {
    const next = new Date(from);
    next.setHours(schedule.send_hour, schedule.send_minute, 0, 0);

    switch (schedule.frequency) {
      case 'daily':
        next.setDate(next.getDate() + 1);
        break;

      case 'weekly':
        next.setDate(next.getDate() + 7);
        break;

      case 'biweekly':
        next.setDate(next.getDate() + 14);
        break;

      case 'monthly':
        next.setMonth(next.getMonth() + 1);
        break;
    }

    return next;
  }

  /**
   * Gera os dados do relatório para um usuário
   */
  async generateReportData(userId, frequency, now) {
    const { startDate, endDate } = this.getDateRange(frequency, now);

    // Busca tipos de conta do usuário
    const types = await AccountType.findAll({
      where: { user_id: userId, deleted_at: null }
    });

    const recebimentosTypeIds = types
      .filter(t => t.name.trim().toLowerCase() === 'recebimentos')
      .map(t => t.id);

    // Busca TODAS as contas do usuário (sem filtro de data no SQL)
    // O filtro de data será feito em JavaScript para maior precisão
    const accounts = await Account.findAll({
      where: {
        user_id: userId,
        deleted_at: null,
        card_brand: null, // Exclui cartões de crédito
        month: { [Op.ne]: null },
        year: { [Op.ne]: null }
      }
    });

    logger.info(`[Email Report] User ${userId}: Found ${accounts.length} accounts total`);
    logger.info(`[Email Report] Date range: ${startDate.toISOString()} to ${endDate.toISOString()}`);

    // Busca pagamentos para verificar status
    const accountIds = accounts.map(a => a.id);
    const payments = await Payment.findAll({
      where: {
        account_id: { [Op.in]: accountIds },
        deleted_at: null
      }
    });

    // Cria mapa de pagamentos por conta
    const paymentMap = new Map();
    for (const payment of payments) {
      if (!paymentMap.has(payment.account_id)) {
        paymentMap.set(payment.account_id, []);
      }
      paymentMap.get(payment.account_id).push(payment);
    }

    // Filtra e organiza contas
    const contasPagar = [];
    const contasReceber = [];
    let totalPagar = 0;
    let totalReceber = 0;

    for (const account of accounts) {
      const dueDate = new Date(account.year, account.month - 1, account.due_day);

      // Verifica se está no período
      if (dueDate < startDate || dueDate > endDate) continue;

      const isRecebimento = recebimentosTypeIds.includes(account.type_id);
      const value = parseFloat(account.value) || parseFloat(account.estimated_value) || 0;

      // Verifica se está pago baseado nos pagamentos
      const accountPayments = paymentMap.get(account.id) || [];
      const isPaid = accountPayments.some(p => {
        const paymentValue = parseFloat(p.value) || 0;
        return paymentValue >= value;
      });

      const accountData = {
        description: account.description,
        dueDate: dueDate.toISOString(),
        value,
        isPaid
      };

      if (isRecebimento) {
        contasReceber.push(accountData);
        totalReceber += value;
      } else {
        contasPagar.push(accountData);
        totalPagar += value;
      }
    }

    logger.info(`[Email Report] Filtered: ${contasPagar.length} to pay, ${contasReceber.length} to receive`);
    logger.info(`[Email Report] Totals: Pay=${totalPagar}, Receive=${totalReceber}`);

    // Ordena por data de vencimento
    contasPagar.sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate));
    contasReceber.sort((a, b) => new Date(a.dueDate) - new Date(b.dueDate));

    // Busca nome do usuário
    const user = await User.findByPk(userId);

    return {
      userName: user.name || 'Usuário',
      date: this.formatDateRange(startDate, endDate),
      contasPagar,
      contasReceber,
      totalPagar,
      totalReceber
    };
  }

  /**
   * Obtém o intervalo de datas baseado na frequência
   */
  getDateRange(frequency, now) {
    const startDate = new Date(now);
    const endDate = new Date(now);

    switch (frequency) {
      case 'daily':
        startDate.setHours(0, 0, 0, 0);
        endDate.setHours(23, 59, 59, 999);
        break;

      case 'weekly':
        // Próximos 7 dias
        startDate.setHours(0, 0, 0, 0);
        endDate.setDate(endDate.getDate() + 7);
        endDate.setHours(23, 59, 59, 999);
        break;

      case 'biweekly':
        // Próximos 14 dias
        startDate.setHours(0, 0, 0, 0);
        endDate.setDate(endDate.getDate() + 14);
        endDate.setHours(23, 59, 59, 999);
        break;

      case 'monthly':
        // Próximos 30 dias
        startDate.setHours(0, 0, 0, 0);
        endDate.setDate(endDate.getDate() + 30);
        endDate.setHours(23, 59, 59, 999);
        break;
    }

    return { startDate, endDate };
  }

  /**
   * Verifica se duas datas são do mesmo dia
   */
  isSameDay(date1, date2) {
    return date1.getFullYear() === date2.getFullYear() &&
           date1.getMonth() === date2.getMonth() &&
           date1.getDate() === date2.getDate();
  }

  /**
   * Formata uma data no formato brasileiro
   */
  formatDate(date) {
    return date.toLocaleDateString('pt-BR');
  }

  /**
   * Formata um intervalo de datas
   */
  formatDateRange(startDate, endDate) {
    if (this.isSameDay(startDate, endDate)) {
      return this.formatDate(startDate);
    }
    return `${this.formatDate(startDate)} a ${this.formatDate(endDate)}`;
  }
}

// Singleton
const schedulerService = new SchedulerService();

module.exports = schedulerService;
