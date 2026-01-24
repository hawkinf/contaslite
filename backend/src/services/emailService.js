/**
 * Serviço de Email - Envia emails usando nodemailer
 */
const nodemailer = require('nodemailer');
const logger = require('../utils/logger');

class EmailService {
  constructor() {
    this.transporter = null;
    this.initialized = false;
  }

  /**
   * Inicializa o transportador de email
   */
  initialize() {
    if (this.initialized) return;

    const host = process.env.SMTP_HOST;
    const port = parseInt(process.env.SMTP_PORT || '587');
    const secure = process.env.SMTP_SECURE === 'true';
    const user = process.env.SMTP_USER;
    const pass = process.env.SMTP_PASS;

    if (!host || !user || !pass) {
      logger.warn('Email service not configured. Missing SMTP credentials.');
      return;
    }

    this.transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: { user, pass }
    });

    this.initialized = true;
    logger.info('Email service initialized');
  }

  /**
   * Verifica se o serviço está configurado
   */
  isConfigured() {
    return this.initialized && this.transporter !== null;
  }

  /**
   * Envia um email
   * @param {string} to - Email do destinatário
   * @param {string} subject - Assunto
   * @param {string} html - Corpo do email em HTML
   */
  async sendEmail(to, subject, html) {
    if (!this.isConfigured()) {
      throw new Error('Email service not configured');
    }

    const fromName = process.env.SMTP_FROM_NAME || 'Contaslite';
    const fromEmail = process.env.SMTP_FROM_EMAIL || process.env.SMTP_USER;

    try {
      const info = await this.transporter.sendMail({
        from: `"${fromName}" <${fromEmail}>`,
        to,
        subject,
        html
      });

      logger.info(`Email sent: ${info.messageId}`);
      return { success: true, messageId: info.messageId };
    } catch (error) {
      logger.error('Failed to send email:', error);
      throw error;
    }
  }

  /**
   * Gera o HTML do relatório de contas
   * @param {Object} data - Dados do relatório
   */
  generateAccountsReportHtml(data) {
    const { userName, date, contasPagar, contasReceber, totalPagar, totalReceber } = data;

    const formatCurrency = (value) => {
      return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL'
      }).format(value);
    };

    const formatDate = (dateStr) => {
      const d = new Date(dateStr);
      return d.toLocaleDateString('pt-BR');
    };

    const renderAccountRow = (account, isPayable) => {
      const color = isPayable ? '#dc3545' : '#28a745';
      const statusLabel = account.isPaid ? '✓ Pago' : 'Pendente';
      const statusColor = account.isPaid ? '#28a745' : '#ffc107';

      return `
        <tr style="border-bottom: 1px solid #eee;">
          <td style="padding: 12px 8px;">${account.description}</td>
          <td style="padding: 12px 8px;">${formatDate(account.dueDate)}</td>
          <td style="padding: 12px 8px; color: ${color}; font-weight: bold;">
            ${formatCurrency(account.value)}
          </td>
          <td style="padding: 12px 8px; color: ${statusColor};">${statusLabel}</td>
        </tr>
      `;
    };

    const tableHeader = `
      <tr style="background-color: #f8f9fa;">
        <th style="padding: 12px 8px; text-align: left;">Descrição</th>
        <th style="padding: 12px 8px; text-align: left;">Vencimento</th>
        <th style="padding: 12px 8px; text-align: left;">Valor</th>
        <th style="padding: 12px 8px; text-align: left;">Status</th>
      </tr>
    `;

    const contasPagarHtml = contasPagar.length > 0
      ? contasPagar.map(a => renderAccountRow(a, true)).join('')
      : '<tr><td colspan="4" style="padding: 12px 8px; text-align: center; color: #6c757d;">Nenhuma conta a pagar</td></tr>';

    const contasReceberHtml = contasReceber.length > 0
      ? contasReceber.map(a => renderAccountRow(a, false)).join('')
      : '<tr><td colspan="4" style="padding: 12px 8px; text-align: center; color: #6c757d;">Nenhuma conta a receber</td></tr>';

    return `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
      </head>
      <body style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 700px; margin: 0 auto; padding: 20px; background-color: #f5f5f5;">
        <div style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); overflow: hidden;">
          <!-- Header -->
          <div style="background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%); color: white; padding: 24px; text-align: center;">
            <h1 style="margin: 0; font-size: 24px;">📊 Relatório de Contas</h1>
            <p style="margin: 8px 0 0 0; opacity: 0.9;">${date}</p>
          </div>

          <!-- Greeting -->
          <div style="padding: 24px;">
            <p style="margin: 0 0 20px 0; font-size: 16px;">
              Olá <strong>${userName}</strong>, aqui está seu resumo de contas:
            </p>

            <!-- Summary Cards -->
            <div style="display: flex; gap: 16px; margin-bottom: 24px;">
              <div style="flex: 1; background-color: #fee2e2; border-radius: 8px; padding: 16px; text-align: center;">
                <p style="margin: 0; color: #991b1b; font-size: 12px; text-transform: uppercase;">Total a Pagar</p>
                <p style="margin: 8px 0 0 0; font-size: 24px; font-weight: bold; color: #dc2626;">
                  ${formatCurrency(totalPagar)}
                </p>
              </div>
              <div style="flex: 1; background-color: #dcfce7; border-radius: 8px; padding: 16px; text-align: center;">
                <p style="margin: 0; color: #166534; font-size: 12px; text-transform: uppercase;">Total a Receber</p>
                <p style="margin: 8px 0 0 0; font-size: 24px; font-weight: bold; color: #16a34a;">
                  ${formatCurrency(totalReceber)}
                </p>
              </div>
            </div>

            <!-- Contas a Pagar -->
            <h2 style="color: #dc2626; font-size: 18px; margin: 24px 0 12px 0; padding-bottom: 8px; border-bottom: 2px solid #dc2626;">
              💸 Contas a Pagar (${contasPagar.length})
            </h2>
            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
              ${tableHeader}
              ${contasPagarHtml}
            </table>

            <!-- Contas a Receber -->
            <h2 style="color: #16a34a; font-size: 18px; margin: 24px 0 12px 0; padding-bottom: 8px; border-bottom: 2px solid #16a34a;">
              💰 Contas a Receber (${contasReceber.length})
            </h2>
            <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
              ${tableHeader}
              ${contasReceberHtml}
            </table>
          </div>

          <!-- Footer -->
          <div style="background-color: #f8f9fa; padding: 16px; text-align: center; border-top: 1px solid #e5e7eb;">
            <p style="margin: 0; color: #6b7280; font-size: 12px;">
              Este email foi enviado automaticamente pelo Contaslite.
            </p>
          </div>
        </div>
      </body>
      </html>
    `;
  }
}

// Singleton
const emailService = new EmailService();

module.exports = emailService;
