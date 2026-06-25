export const inviteChannelConfig = {
  officialAccountName: '化语智答',
  replyKeywords: ['邀请码'],
  qrCodeImageUrl: ''
} as const;

export function buildInviteChannelGuide() {
  return [
    '获取化语智答邀请码方式：',
    `1. 微信搜索并关注公众号${inviteChannelConfig.officialAccountName}`,
    `2. 后台回复【${inviteChannelConfig.replyKeywords.join('】、【')}】`,
    '3. 收到邀请码后，回到注册页继续完成注册'
  ].join('\n');
}

export function buildInviteCodeShareMessage(shareLink: string, inviteCode: string) {
  return [
    '化语智答是面向高校师生的智能问答系统，欢迎体验。',
    `邀请码：${inviteCode}`,
    `注册链接：${shareLink}`,
    '',
    `如果邀请码失效，或者想帮朋友再领取一个，也可以关注公众号【${inviteChannelConfig.officialAccountName}】`,
    `后台回复【${inviteChannelConfig.replyKeywords.join('】、【')}】即可获取最新邀请码。`
  ].join('\n');
}
