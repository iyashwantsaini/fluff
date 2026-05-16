package dev.fluff.documents_provider

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsProvider

/**
 * Reusable [DocumentsProvider] backed by a cached Flutter engine.
 *
 * Status: scaffold. All callbacks currently return empty cursors. The
 * production implementation will spin up a background [FlutterEngine]
 * via `FlutterEngineGroup` on first use, then proxy every method to
 * Dart over the [FluffDocumentsProviderPlugin] channel.
 *
 * See PLAN.md §4.3.
 */
class FluffDocumentsProvider : DocumentsProvider() {

    companion object {
        private val DEFAULT_ROOT_PROJECTION = arrayOf(
            DocumentsContract.Root.COLUMN_ROOT_ID,
            DocumentsContract.Root.COLUMN_FLAGS,
            DocumentsContract.Root.COLUMN_TITLE,
            DocumentsContract.Root.COLUMN_DOCUMENT_ID,
            DocumentsContract.Root.COLUMN_ICON,
        )

        private val DEFAULT_DOCUMENT_PROJECTION = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_FLAGS,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
    }

    override fun onCreate(): Boolean = true

    override fun queryRoots(projection: Array<out String>?): Cursor {
        // TODO(phase-6): ask the cached Dart isolate for roots.
        return MatrixCursor(projection ?: DEFAULT_ROOT_PROJECTION)
    }

    override fun queryDocument(
        documentId: String,
        projection: Array<out String>?,
    ): Cursor {
        return MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        return MatrixCursor(projection ?: DEFAULT_DOCUMENT_PROJECTION)
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?,
    ): ParcelFileDescriptor? {
        // TODO(phase-6): build a ParcelFileDescriptor pipe and stream
        // bytes from the Dart-side FsProvider.
        return null
    }
}
