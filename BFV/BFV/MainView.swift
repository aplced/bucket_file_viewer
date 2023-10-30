//
//  MainView.swift
//  BFV
//
//  Created by Atanas on 29.10.23.
//

import SwiftUI
import AWSClientRuntime
import AWSS3

struct MainView: View {
    @AppStorage("bfvKey")  var accessKey: String = ""
    @AppStorage("bfvSecret") var secret: String = ""
    
    var body: some View {
        NavigationView {
                Form{
                    TextField(text: $accessKey, prompt: Text("Key")){
                        Text("Key")
                    }
                    TextField(text: $secret, prompt: Text("Secret")) {
                        Text("Secret")
                    }
                    NavigationLink(
                        "Login",
                        destination: BucketNameView(accessKey: accessKey, secret: secret)
                    ).disabled(accessKey == "" || secret == "")
                }
        }
        .navigationTitle("Account login")
    }
}

struct BucketNameView: View {
    @State var s3Client: S3Client? = nil
    @State var loggedIn: Bool = false
    @AppStorage("bfvBucketName")  var bucketName = ""
    @State var directories: [String]?
    let accessKey: String
    let secret: String
    
    var body: some View {
        Form{
            TextField(text: $bucketName, prompt: Text("Bucket")) {
                HStack{
                    Text("Bucket")
                }
            }
            NavigationLink(
                "Fetch",
                destination: ContentView(s3Client: s3Client, bucketName: bucketName, prefix: nil)
            ).disabled(bucketName == "")
        }
        .navigationTitle("s3 bucket name")
        .task {
            await createS3Client()
            loggedIn = s3Client != nil
        }
    }
    
    func createS3Client() async {
        do {
            let credentialsP = try AWSClientRuntime.StaticCredentialsProvider(AWSClientRuntime.AWSCredentials(accessKey: accessKey, secret: secret))
            let clientConfig = try S3Client.S3ClientConfiguration(region: "eu-central-1", credentialsProvider: credentialsP)
            s3Client = S3Client(config: clientConfig)
        } catch {
           dump(error)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
