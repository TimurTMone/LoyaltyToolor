"use client";

import { useState, useRef } from "react";
import apiClient from "@/lib/api-client";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Upload, FileSpreadsheet, CheckCircle2, AlertCircle } from "lucide-react";
import { toast } from "sonner";

type ImportResult = {
  ok: boolean;
  filename: string;
  products_parsed: number;
  products_inserted: number;
  categories_created: number;
  subcategories_created: number;
};

export default function ImportPage() {
  const [file, setFile] = useState<File | null>(null);
  const [replaceAll, setReplaceAll] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [result, setResult] = useState<ImportResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  function handleFile(f: File | undefined) {
    setError(null);
    setResult(null);
    if (!f) return;
    if (!f.name.toLowerCase().endsWith(".xlsx") && !f.name.toLowerCase().endsWith(".xlsm")) {
      setError("Загрузите .xlsx файл");
      return;
    }
    setFile(f);
  }

  async function handleUpload() {
    if (!file) return;
    setUploading(true);
    setError(null);
    setResult(null);
    try {
      const formData = new FormData();
      formData.append("file", file);
      const res = await apiClient.post<ImportResult>(
        `/api/v1/admin/products/import-excel?replace_all=${replaceAll}`,
        formData,
        { headers: { "Content-Type": "multipart/form-data" } }
      );
      setResult(res.data);
      toast.success(`Импортировано ${res.data.products_inserted} товаров`);
    } catch (e: unknown) {
      const message =
        (e as { response?: { data?: { detail?: string } } })?.response?.data?.detail ||
        (e as Error)?.message ||
        "Ошибка загрузки";
      setError(message);
      toast.error(message);
    } finally {
      setUploading(false);
    }
  }

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="text-2xl font-bold">Импорт из Excel</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Загрузите Excel-файл с инвентарём TOOLOR. Автоматически обновит товары, категории и склад.
        </p>
      </div>

      {/* Drag-drop zone */}
      <div
        onDragOver={(e) => {
          e.preventDefault();
          setDragOver(true);
        }}
        onDragLeave={() => setDragOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setDragOver(false);
          handleFile(e.dataTransfer.files[0]);
        }}
        onClick={() => inputRef.current?.click()}
        className={`border-2 border-dashed rounded-xl p-10 text-center cursor-pointer transition-colors ${
          dragOver ? "border-primary bg-primary/5" : "border-border hover:border-primary/50"
        }`}
      >
        <input
          ref={inputRef}
          type="file"
          accept=".xlsx,.xlsm"
          className="hidden"
          onChange={(e) => handleFile(e.target.files?.[0])}
        />
        {file ? (
          <div className="flex items-center justify-center gap-3">
            <FileSpreadsheet className="w-8 h-8 text-primary" />
            <div className="text-left">
              <div className="font-medium">{file.name}</div>
              <div className="text-xs text-muted-foreground">
                {(file.size / 1024).toFixed(1)} KB
              </div>
            </div>
          </div>
        ) : (
          <>
            <Upload className="w-10 h-10 mx-auto text-muted-foreground mb-3" />
            <p className="font-medium">Перетащите .xlsx файл сюда</p>
            <p className="text-xs text-muted-foreground mt-1">или нажмите для выбора</p>
          </>
        )}
      </div>

      {/* Replace-all toggle */}
      <div className="flex items-center justify-between border rounded-lg p-4">
        <div>
          <Label htmlFor="replace-all" className="font-medium">
            Заменить все товары
          </Label>
          <p className="text-xs text-muted-foreground mt-1">
            Удалит существующие товары и категории перед загрузкой
          </p>
        </div>
        <Switch id="replace-all" checked={replaceAll} onCheckedChange={setReplaceAll} />
      </div>

      {/* Upload button */}
      <Button
        onClick={handleUpload}
        disabled={!file || uploading}
        className="w-full"
        size="lg"
      >
        {uploading ? "Импорт..." : "Загрузить и импортировать"}
      </Button>

      {/* Error */}
      {error && (
        <div className="flex gap-3 bg-destructive/10 border border-destructive/30 rounded-lg p-4">
          <AlertCircle className="w-5 h-5 text-destructive flex-shrink-0" />
          <div className="text-sm text-destructive">{error}</div>
        </div>
      )}

      {/* Success */}
      {result && (
        <div className="border rounded-lg p-5 space-y-3 bg-green-50 dark:bg-green-950/20 border-green-200 dark:border-green-900">
          <div className="flex items-center gap-2 text-green-700 dark:text-green-400 font-semibold">
            <CheckCircle2 className="w-5 h-5" />
            Импорт завершён
          </div>
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <div className="text-muted-foreground">Товары:</div>
              <div className="font-semibold">{result.products_inserted}</div>
            </div>
            <div>
              <div className="text-muted-foreground">Категории:</div>
              <div className="font-semibold">{result.categories_created}</div>
            </div>
            <div>
              <div className="text-muted-foreground">Подкатегории:</div>
              <div className="font-semibold">{result.subcategories_created}</div>
            </div>
            <div>
              <div className="text-muted-foreground">Обработано:</div>
              <div className="font-semibold">{result.products_parsed}</div>
            </div>
          </div>
        </div>
      )}

      {/* Format hint */}
      <details className="text-sm border rounded-lg p-4 bg-muted/30">
        <summary className="cursor-pointer font-medium">Формат Excel файла</summary>
        <div className="mt-3 space-y-2 text-muted-foreground">
          <p>Каждый лист = категория (например: «2576 Куртки для взрослых»).</p>
          <p>Обязательные колонки:</p>
          <ul className="list-disc list-inside ml-2 space-y-1">
            <li>Уникальный идентификатор товара (SKU)</li>
            <li>Наименование товара</li>
            <li>Цена товара</li>
            <li>Размер, Название цвета от производителя</li>
            <li>Ссылки на изображения товара (через запятую)</li>
            <li>Объединить карточки в одну по SKU</li>
            <li>ТЦ Азия молл 2 этаж (количество на складе)</li>
          </ul>
        </div>
      </details>
    </div>
  );
}
