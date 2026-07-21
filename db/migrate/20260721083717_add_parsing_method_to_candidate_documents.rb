class AddParsingMethodToCandidateDocuments < ActiveRecord::Migration[8.1]
  def change
    # Distinguishes a real AI extraction from the no-API-key regex fallback,
    # so the UI can be honest about which one actually ran.
    add_column :candidate_documents, :parsing_method, :integer
  end
end
