/**
 * Controller para gerenciamento de configurações de email
 */
const { EmailSchedule } = require('../models');
const emailService = require('../services/emailService');
const schedulerService = require('../services/schedulerService');
const logger = require('../utils/logger');

/**
 * GET /api/email/settings - Obtém configurações de email do usuário
 */
const getSettings = async (req, res) => {
  try {
    const userId = req.userId;

    let schedule = await EmailSchedule.findOne({
      where: { user_id: userId }
    });

    // Se não existe, cria com valores padrão
    if (!schedule) {
      schedule = await EmailSchedule.create({
        user_id: userId,
        is_enabled: false,
        frequency: 'daily',
        send_hour: 3,
        send_minute: 0,
        weekly_day: 1,
        monthly_day: 1
      });
    }

    res.json({
      success: true,
      data: {
        isEnabled: schedule.is_enabled,
        frequency: schedule.frequency,
        sendHour: schedule.send_hour,
        sendMinute: schedule.send_minute,
        weeklyDay: schedule.weekly_day,
        monthlyDay: schedule.monthly_day,
        lastSentAt: schedule.last_sent_at,
        nextSendAt: schedule.next_send_at
      }
    });
  } catch (error) {
    logger.error('Error getting email settings:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao obter configurações de email'
    });
  }
};

/**
 * PUT /api/email/settings - Atualiza configurações de email
 */
const updateSettings = async (req, res) => {
  try {
    const userId = req.userId;
    const {
      isEnabled,
      frequency,
      sendHour,
      sendMinute,
      weeklyDay,
      monthlyDay
    } = req.body;

    // Validações
    if (frequency && !['daily', 'weekly', 'biweekly', 'monthly'].includes(frequency)) {
      return res.status(400).json({
        success: false,
        error: 'Frequência inválida'
      });
    }

    if (sendHour !== undefined && (sendHour < 0 || sendHour > 23)) {
      return res.status(400).json({
        success: false,
        error: 'Hora de envio inválida (0-23)'
      });
    }

    if (sendMinute !== undefined && (sendMinute < 0 || sendMinute > 59)) {
      return res.status(400).json({
        success: false,
        error: 'Minuto de envio inválido (0-59)'
      });
    }

    if (weeklyDay !== undefined && (weeklyDay < 0 || weeklyDay > 6)) {
      return res.status(400).json({
        success: false,
        error: 'Dia da semana inválido (0-6, onde 0=Domingo)'
      });
    }

    if (monthlyDay !== undefined && (monthlyDay < 1 || monthlyDay > 28)) {
      return res.status(400).json({
        success: false,
        error: 'Dia do mês inválido (1-28)'
      });
    }

    let schedule = await EmailSchedule.findOne({
      where: { user_id: userId }
    });

    if (!schedule) {
      schedule = await EmailSchedule.create({
        user_id: userId
      });
    }

    // Atualiza os campos
    if (isEnabled !== undefined) schedule.is_enabled = isEnabled;
    if (frequency !== undefined) schedule.frequency = frequency;
    if (sendHour !== undefined) schedule.send_hour = sendHour;
    if (sendMinute !== undefined) schedule.send_minute = sendMinute;
    if (weeklyDay !== undefined) schedule.weekly_day = weeklyDay;
    if (monthlyDay !== undefined) schedule.monthly_day = monthlyDay;

    // Calcula próximo envio se habilitado
    if (schedule.is_enabled) {
      schedule.next_send_at = schedulerService.calculateNextSend(schedule, new Date());
    } else {
      schedule.next_send_at = null;
    }

    schedule.updated_at = new Date();
    await schedule.save();

    res.json({
      success: true,
      data: {
        isEnabled: schedule.is_enabled,
        frequency: schedule.frequency,
        sendHour: schedule.send_hour,
        sendMinute: schedule.send_minute,
        weeklyDay: schedule.weekly_day,
        monthlyDay: schedule.monthly_day,
        lastSentAt: schedule.last_sent_at,
        nextSendAt: schedule.next_send_at
      }
    });
  } catch (error) {
    logger.error('Error updating email settings:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao atualizar configurações de email'
    });
  }
};

/**
 * POST /api/email/test - Envia um email de teste
 */
const sendTestEmail = async (req, res) => {
  try {
    const user = req.user;

    if (!emailService.isConfigured()) {
      return res.status(503).json({
        success: false,
        error: 'Serviço de email não configurado no servidor'
      });
    }

    // Gera dados de exemplo para o teste
    const testData = {
      userName: user.name || 'Usuário',
      date: new Date().toLocaleDateString('pt-BR'),
      contasPagar: [
        { description: 'Conta de Luz (Teste)', dueDate: new Date().toISOString(), value: 150.00, isPaid: false },
        { description: 'Internet (Teste)', dueDate: new Date().toISOString(), value: 120.00, isPaid: true }
      ],
      contasReceber: [
        { description: 'Aluguel (Teste)', dueDate: new Date().toISOString(), value: 2000.00, isPaid: false }
      ],
      totalPagar: 270.00,
      totalReceber: 2000.00
    };

    const html = emailService.generateAccountsReportHtml(testData);
    await emailService.sendEmail(user.email, '🧪 Email de Teste - Contaslite', html);

    res.json({
      success: true,
      message: `Email de teste enviado para ${user.email}`
    });
  } catch (error) {
    logger.error('Error sending test email:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao enviar email de teste: ' + error.message
    });
  }
};

/**
 * GET /api/email/status - Verifica status do serviço de email
 */
const getStatus = async (req, res) => {
  try {
    res.json({
      success: true,
      data: {
        configured: emailService.isConfigured(),
        schedulerRunning: schedulerService.initialized
      }
    });
  } catch (error) {
    logger.error('Error getting email status:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao verificar status do email'
    });
  }
};

module.exports = {
  getSettings,
  updateSettings,
  sendTestEmail,
  getStatus
};
