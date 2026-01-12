const express = require('express');
const router = express.Router();
const authenticate = require('../middleware/authenticate');
const Account = require('../models/Account');
const AccountType = require('../models/AccountType');
const AccountDescription = require('../models/AccountDescription');
const PaymentMethod = require('../models/PaymentMethod');
const Bank = require('../models/Bank');

/**
 * DELETE /api/user/data
 * Exclui todos os dados do usuário autenticado
 */
router.delete('/data', authenticate, async (req, res) => {
  const transaction = await Account.sequelize.transaction();

  try {
    const userId = req.user.id;

    // Contar registros antes
    const beforeCounts = {
      accounts: await Account.count({ where: { user_id: userId } }),
      accountTypes: await AccountType.count({ where: { user_id: userId } }),
      accountDescriptions: await AccountDescription.count({ where: { user_id: userId } }),
      paymentMethods: await PaymentMethod.count({ where: { user_id: userId } }),
      banks: await Bank.count({ where: { user_id: userId } }),
    };

    // Deletar em ordem para respeitar foreign keys
    await Account.destroy({
      where: { user_id: userId },
      transaction,
    });

    await AccountType.destroy({
      where: { user_id: userId },
      transaction,
    });

    await AccountDescription.destroy({
      where: { user_id: userId },
      transaction,
    });

    await PaymentMethod.destroy({
      where: { user_id: userId },
      transaction,
    });

    await Bank.destroy({
      where: { user_id: userId },
      transaction,
    });

    await transaction.commit();

    console.log('User data deleted for user', userId, beforeCounts);

    res.json({
      success: true,
      message: 'Todos os dados foram excluídos com sucesso',
      deleted: beforeCounts,
    });
  } catch (error) {
    await transaction.rollback();
    console.error('❌ Erro ao excluir dados do usuário:', error);
    res.status(500).json({
      error: 'Erro ao excluir dados',
      message: error.message,
    });
  }
});

module.exports = router;
