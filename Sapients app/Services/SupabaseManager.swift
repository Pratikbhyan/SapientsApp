import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // TODO: Replace with your actual Supabase URL and anon key
        guard let supabaseURL = URL(string: "YOUR_SUPABASE_URL") else {
            fatalError("Invalid Supabase URL")
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: "YOUR_SUPABASE_ANON_KEY"
        )
    }
} 