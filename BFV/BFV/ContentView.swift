//
//  ContentView.swift
//  BFV
//
//  Created by Atanas on 26.10.23.
//

import SwiftUI
import AWSS3

struct ContentView: View {
    @State var bucketLevelContents: BucketLevelContents?
    let s3Client: S3Client?
    let bucketName: String
    let prefix: String?
    
    var body: some View {
        ScrollView {
            VStack {
                if let directories = bucketLevelContents?.directories {
                    ForEach(directories, id: \.self) { directory in
                        ZStack{
                            RoundedRectangle(cornerRadius: 25.0)
                                .fill(Color.blue)
                                .frame(width: .infinity, height: 100)
                                .shadow(radius: 10)
                            NavigationLink(
                                directory,
                                destination: ContentView(s3Client: s3Client, bucketName: bucketName, prefix: (prefix != nil ? prefix! : "") + "\(directory)/")
                            ).foregroundColor(Color.white)
                        }
                    }
                }
                if let files = bucketLevelContents?.files {
                    ForEach(files, id: \.self) { file in
                        ZStack{
                            RoundedRectangle(cornerRadius: 25.0)
                                .frame(width: .infinity, height: 100)
                                .shadow(radius: 10)
                            Button(file, action: {
                                if let s3Client = s3Client {
                                    Task {
                                        do{
                                            try await downloadFile(s3Client: s3Client, bucket: bucketName, key: "\(prefix ?? "")\(file)")
                                        } catch {
                                            dump(error)
                                        }
                                    }
                                }
                            })
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("\(prefix ?? bucketName)")
            .task {
                print("fetching contents of: \(bucketName)\(prefix != nil ? "/" + prefix! : "")")
                bucketLevelContents = await listBucketContents(s3Client: s3Client, bucketName: bucketName, prefix: prefix)
            }
        }
    }
}

struct BucketLevelContents {
    var directories: [String]?
    var files: [String]?
}

func listBucketContents(s3Client: S3Client?, bucketName: String, prefix: String?) async -> BucketLevelContents?  {
    do {
        let listObjectsResponse = try await s3Client?.listObjectsV2(input: ListObjectsV2Input(
            bucket: bucketName,
            delimiter: "/",
            prefix: prefix
        ))
        var blc = BucketLevelContents()
        if let commonPfx = listObjectsResponse?.commonPrefixes {
            //print("\(commonPfx)")
            blc.directories = commonPfx.map{
                if let directory = $0.prefix {
                    if let prefix = prefix {
                        return directory
                            .replacingOccurrences(of: prefix, with: "")
                            .replacingOccurrences(of: "/", with: "")
                    } else {
                        return directory.replacingOccurrences(of: "/", with: "")
                    }
                } else {
                    return ""
                }
            }
        }
        blc.directories?.removeAll(where: { directory in
            directory == ""
        })
        if let contents = listObjectsResponse?.contents {
            blc.files = contents.map{
                if let key = $0.key {
                    //print("\(key) modified: \($0.lastModified!)")
                    if let prefix = prefix {
                        return key.replacingOccurrences(of: prefix, with: "").replacingOccurrences(of: "/", with: "")
                    } else {
                        return key.replacingOccurrences(of: "/", with: "")
                    }
                } else {
                    return ""
                }
            }
        }
        blc.files?.removeAll(where: { file in
            file == ""
        })
        return blc
    } catch {
        dump(error)
        return nil
    }
}

func downloadFile(s3Client: S3Client, bucket: String, key: String) async throws {
    let asd = URL(fileURLWithPath: key)
    try FileManager.default.createDirectory(at: .downloadsDirectory.appendingPathComponent(asd.deletingLastPathComponent().path()), withIntermediateDirectories: true)
    
    let fileUrl = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent(key)
    print("Downloading \(bucket) file \(key) to \(fileUrl)")
    let input = GetObjectInput(
        bucket: bucket,
        key: key
    )
    let output = try await s3Client.getObject(input: input)

    // Get the data stream object. Return immediately if there isn't one.
    guard let body = output.body,
          let data = try await body.readData() else {
        return
    }
    try data.write(to: fileUrl)
    await UIApplication.shared.open(fileUrl, completionHandler: {success in
        print("URL open action success status: \(success)")
    })
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            s3Client: nil,
            bucketName: "None",
            prefix: nil
        )
    }
}
