<script setup lang="ts">
import { uploadAccept } from '@/constants/common';

defineOptions({
  name: 'UploadDialog'
});

const loading = ref(false);
const visible = defineModel<boolean>('visible', { default: false });
const singleOrgOnly = ref(false);

const authStore = useAuthStore();

const { formRef, validate, restoreValidation } = useNaiveForm();
const { defaultRequiredRule } = useFormRules();

const model = ref<Api.KnowledgeBase.Form>(createDefaultModel());

function createDefaultModel(): Api.KnowledgeBase.Form {
  return {
    deptTag: null,
    deptTagName: '',
    uploadMaxSizeBytes: null,
    uploadMaxSizeMb: null,
    isPublic: false,
    fileList: []
  };
}

const rules = ref<FormRules>({
  deptTag: defaultRequiredRule,
  isPublic: defaultRequiredRule,
  fileList: defaultRequiredRule
});

const fileSizeLimitError = computed(() => {
  if (authStore.isAdmin) return '';
  const file = model.value.fileList?.[0]?.file;
  if (!file || !model.value.uploadMaxSizeBytes) return '';
  if (file.size <= model.value.uploadMaxSizeBytes) return '';

  return `当前组织限制非管理员上传文件不超过 ${model.value.uploadMaxSizeMb} MB，当前文件大小为 ${(file.size / 1024 / 1024).toFixed(2)} MB`;
});

const submitDisabled = computed(() => loading.value || Boolean(fileSizeLimitError.value));

function close() {
  visible.value = false;
}

const store = useKnowledgeBaseStore();
async function handleSubmit() {
  await validate();
  if (fileSizeLimitError.value) return;

  loading.value = true;
  await store.enqueueUpload(model.value);
  loading.value = false;
  close();
}

async function presetSingleOrgForUser() {
  singleOrgOnly.value = false;
  const { error, data } = await request<Api.DeptTag.Mine>({ url: '/users/dept-tags' });
  if (error || !visible.value) return;

  const deptTagDetails = data.deptTagDetails || [];
  if (deptTagDetails.length !== 1) return;

  const singleOrg = deptTagDetails[0];
  model.value.deptTag = singleOrg.tagId;
  onUpdate(singleOrg);
  singleOrgOnly.value = true;
}

watch(visible, () => {
  if (visible.value) {
    model.value = createDefaultModel();
    singleOrgOnly.value = false;
    if (!authStore.isAdmin) {
      presetSingleOrgForUser();
    }
    restoreValidation();
  }
});

function onUpdate(option: unknown) {
  if (option) {
    const selected = option as Api.DeptTag.Item;
    model.value.deptTagName = selected.name;
    model.value.uploadMaxSizeBytes = selected.uploadMaxSizeBytes;
    model.value.uploadMaxSizeMb = selected.uploadMaxSizeMb;
    return;
  }
  model.value.deptTagName = '';
  model.value.uploadMaxSizeBytes = null;
  model.value.uploadMaxSizeMb = null;
}
</script>

<template>
  <NModal
    v-model:show="visible"
    preset="dialog"
    title="文件上传"
    :show-icon="false"
    :mask-closable="false"
    class="w-500px!"
    @positive-click="handleSubmit"
  >
    <NForm ref="formRef" :model="model" :rules="rules" label-placement="left" :label-width="100" mt-10>
      <NFormItem v-if="authStore.isAdmin" label="院系" path="deptTag">
        <DeptTagCascader v-model:value="model.deptTag" @change="onUpdate" />
      </NFormItem>
      <NFormItem v-else label="院系" path="deptTag">
        <TheSelect
          v-model:value="model.deptTag"
          url="/users/dept-tags"
          key-field="deptTagDetails"
          label-field="name"
          value-field="tagId"
          :disabled="singleOrgOnly"
          @change="onUpdate"
        />
      </NFormItem>

      <NFormItem label="是否公开" path="isPublic">
        <NRadioGroup v-model:value="model.isPublic" name="radiogroup">
          <NSpace :size="16">
            <NRadio :value="true">公开</NRadio>
            <NRadio :value="false">私有</NRadio>
          </NSpace>
        </NRadioGroup>
      </NFormItem>
      <NFormItem label="标签描述" path="fileList">
        <NUpload
          v-model:file-list="model.fileList"
          :accept="uploadAccept"
          :max="1"
          :multiple="false"
          :default-upload="false"
        >
          <NButton>上传文件</NButton>
        </NUpload>
        <div v-if="fileSizeLimitError" class="mt-8px text-12px text-#ef4444">
          {{ fileSizeLimitError }}
        </div>
        <div v-else-if="!authStore.isAdmin && model.uploadMaxSizeMb" class="mt-8px text-12px text-#d97706">
          当前组织限制非管理员上传文件不超过 {{ model.uploadMaxSizeMb }} MB
        </div>
      </NFormItem>
    </NForm>
    <template #action>
      <NSpace :size="16">
        <NButton @click="close">取消</NButton>
        <NButton type="primary" :disabled="submitDisabled" @click="handleSubmit">保存</NButton>
      </NSpace>
    </template>
  </NModal>
</template>

<style scoped></style>
